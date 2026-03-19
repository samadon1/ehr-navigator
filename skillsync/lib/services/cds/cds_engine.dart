import '../../models/agent/cds_alert.dart';
import 'drug_interaction.dart';

/// Clinical Decision Support Engine
/// Orchestrates all CDS checkers and returns alerts
class CdsEngine {
  final DrugInteractionChecker _drugInteractionChecker;

  CdsEngine({
    DrugInteractionChecker? drugInteractionChecker,
  }) : _drugInteractionChecker = drugInteractionChecker ?? DrugInteractionChecker();

  /// Run all CDS checks on patient data
  Future<List<CdsAlert>> runAllChecks(Map<String, dynamic> patientData) async {
    final alerts = <CdsAlert>[];

    // Extract data
    final medications =
        (patientData['medications'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final allergies =
        (patientData['allergies'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    // Drug interaction check
    if (medications.isNotEmpty) {
      final drugAlerts = await _drugInteractionChecker.check(
        medications: medications,
        allergies: allergies,
      );
      alerts.addAll(drugAlerts);
    }

    // Sort by severity (critical first)
    alerts.sort((a, b) => b.severity.index.compareTo(a.severity.index));

    return alerts;
  }

  /// Check drug interactions specifically
  Future<List<CdsAlert>> checkDrugInteractions({
    required List<Map<String, dynamic>> medications,
    List<Map<String, dynamic>>? allergies,
    String? proposedMedication,
  }) async {
    return _drugInteractionChecker.check(
      medications: medications,
      allergies: allergies,
      proposedMedication: proposedMedication,
    );
  }

  /// Check if a proposed medication is safe for a patient
  Future<List<CdsAlert>> checkMedicationSafety({
    required List<Map<String, dynamic>> currentMedications,
    required List<Map<String, dynamic>> allergies,
    required String proposedMedication,
  }) async {
    final alerts = <CdsAlert>[];

    // Check drug interactions
    final interactionAlerts = await _drugInteractionChecker.check(
      medications: currentMedications,
      allergies: allergies,
      proposedMedication: proposedMedication,
    );
    alerts.addAll(interactionAlerts);

    // Check allergy contraindications
    final allergyAlerts = _checkAllergyContraindications(
      allergies: allergies,
      proposedMedication: proposedMedication,
    );
    alerts.addAll(allergyAlerts);

    return alerts;
  }

  /// Check for allergy contraindications
  List<CdsAlert> _checkAllergyContraindications({
    required List<Map<String, dynamic>> allergies,
    required String proposedMedication,
  }) {
    final alerts = <CdsAlert>[];
    final proposedLower = proposedMedication.toLowerCase();

    // Cross-reactivity mappings
    const crossReactivity = {
      'penicillin': ['amoxicillin', 'ampicillin', 'piperacillin', 'nafcillin'],
      'sulfa': ['sulfamethoxazole', 'sulfasalazine', 'trimethoprim-sulfamethoxazole'],
      'cephalosporin': ['cefazolin', 'ceftriaxone', 'cephalexin', 'cefuroxime'],
      'nsaid': ['ibuprofen', 'naproxen', 'meloxicam', 'celecoxib', 'aspirin'],
    };

    for (final allergy in allergies) {
      final allergenName = (allergy['allergen'] as String? ?? '').toLowerCase();
      final criticality = allergy['criticality'] as String?;

      // Direct match
      if (proposedLower.contains(allergenName) ||
          allergenName.contains(proposedLower)) {
        alerts.add(CdsAlert(
          type: CdsAlertType.allergyAlert,
          severity: criticality == 'high' ? CdsSeverity.critical : CdsSeverity.high,
          title: 'ALLERGY ALERT: $proposedMedication',
          description:
              'Patient has documented allergy to $allergenName',
          recommendations: [
            'DO NOT administer $proposedMedication',
            'Review allergy history',
            'Consider alternative medication',
          ],
          context: {
            'allergen': allergenName,
            'proposedMedication': proposedMedication,
            'criticality': criticality,
          },
        ));
      }

      // Cross-reactivity check
      for (final entry in crossReactivity.entries) {
        if (allergenName.contains(entry.key)) {
          for (final relatedDrug in entry.value) {
            if (proposedLower.contains(relatedDrug)) {
              alerts.add(CdsAlert(
                type: CdsAlertType.allergyAlert,
                severity: CdsSeverity.high,
                title: 'Potential Cross-Reactivity: $proposedMedication',
                description:
                    'Patient allergic to $allergenName. $proposedMedication may cross-react.',
                recommendations: [
                  'Consider alternative medication',
                  'If must use, monitor closely for allergic reaction',
                  'Have emergency treatment available',
                ],
                context: {
                  'allergen': allergenName,
                  'proposedMedication': proposedMedication,
                  'crossReactivityClass': entry.key,
                },
              ));
            }
          }
        }
      }
    }

    return alerts;
  }

  /// Quick check for any critical issues
  Future<bool> hasCriticalIssues(Map<String, dynamic> patientData) async {
    final alerts = await runAllChecks(patientData);
    return alerts.any((a) => a.severity == CdsSeverity.critical);
  }

  /// Get summary of alerts by severity
  Map<CdsSeverity, int> getAlertSummary(List<CdsAlert> alerts) {
    final summary = <CdsSeverity, int>{};
    for (final severity in CdsSeverity.values) {
      summary[severity] = alerts.where((a) => a.severity == severity).length;
    }
    return summary;
  }
}
