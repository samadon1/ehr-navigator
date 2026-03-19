/// ============================================
/// CLINICAL DECISION SUPPORT (CDS)
/// ============================================
///
/// Rule-based safety checks that run alongside AI
/// Catches dangerous situations like drug interactions

// ---------------------------------------------
// Alert Model
// ---------------------------------------------
enum CdsSeverity { low, moderate, high, critical }

class CdsAlert {
  final String title;
  final String description;
  final CdsSeverity severity;
  final List<String> recommendations;

  CdsAlert({
    required this.title,
    required this.description,
    required this.severity,
    required this.recommendations,
  });
}

// ---------------------------------------------
// Drug Interaction Database
// ---------------------------------------------
class DrugInteraction {
  final String drug1;
  final String drug2;
  final String severity;
  final String description;
  final String recommendation;

  const DrugInteraction({
    required this.drug1,
    required this.drug2,
    required this.severity,
    required this.description,
    required this.recommendation,
  });
}

// Common dangerous interactions
const List<DrugInteraction> interactions = [
  DrugInteraction(
    drug1: 'warfarin',
    drug2: 'aspirin',
    severity: 'severe',
    description: 'Increased risk of serious bleeding',
    recommendation: 'Monitor closely for signs of bleeding',
  ),
  DrugInteraction(
    drug1: 'warfarin',
    drug2: 'ibuprofen',
    severity: 'severe',
    description: 'Increased risk of GI bleeding',
    recommendation: 'Avoid concurrent use. Consider acetaminophen.',
  ),
  DrugInteraction(
    drug1: 'metformin',
    drug2: 'contrast dye',
    severity: 'severe',
    description: 'Risk of lactic acidosis',
    recommendation: 'Hold metformin 48h before/after contrast',
  ),
  DrugInteraction(
    drug1: 'lisinopril',
    drug2: 'potassium',
    severity: 'moderate',
    description: 'Risk of hyperkalemia',
    recommendation: 'Monitor serum potassium levels',
  ),
  DrugInteraction(
    drug1: 'oxycodone',
    drug2: 'benzodiazepine',
    severity: 'severe',
    description: 'Risk of respiratory depression and death',
    recommendation: 'Avoid concurrent use if possible',
  ),
  DrugInteraction(
    drug1: 'sertraline',
    drug2: 'tramadol',
    severity: 'severe',
    description: 'Risk of serotonin syndrome',
    recommendation: 'Choose alternative pain management',
  ),
];

// ---------------------------------------------
// CDS Engine
// ---------------------------------------------
class CdsEngine {

  /// Check all medications for interactions
  Future<List<CdsAlert>> checkDrugInteractions(List<String> medications) async {
    final alerts = <CdsAlert>[];

    // Check all pairs of medications
    for (var i = 0; i < medications.length; i++) {
      for (var j = i + 1; j < medications.length; j++) {
        final med1 = medications[i].toLowerCase();
        final med2 = medications[j].toLowerCase();

        // Find matching interaction
        final interaction = _findInteraction(med1, med2);
        if (interaction != null) {
          alerts.add(_createAlert(interaction, med1, med2));
        }
      }
    }

    return alerts;
  }

  DrugInteraction? _findInteraction(String med1, String med2) {
    for (final interaction in interactions) {
      // Check both directions
      if ((med1.contains(interaction.drug1) && med2.contains(interaction.drug2)) ||
          (med1.contains(interaction.drug2) && med2.contains(interaction.drug1))) {
        return interaction;
      }
    }
    return null;
  }

  CdsAlert _createAlert(DrugInteraction interaction, String med1, String med2) {
    return CdsAlert(
      title: 'Drug Interaction: $med1 + $med2',
      description: interaction.description,
      severity: interaction.severity == 'severe'
          ? CdsSeverity.critical
          : CdsSeverity.high,
      recommendations: [interaction.recommendation],
    );
  }
}


// ---------------------------------------------
// Example Usage
// ---------------------------------------------
void main() async {
  final cds = CdsEngine();

  // Patient's current medications
  final medications = ['Warfarin 5mg', 'Aspirin 81mg', 'Metformin 500mg'];

  // Check for interactions
  final alerts = await cds.checkDrugInteractions(medications);

  for (final alert in alerts) {
    print('⚠️ ${alert.title}');
    print('   ${alert.description}');
    print('   Recommendation: ${alert.recommendations.first}');
  }

  // Output:
  // ⚠️ Drug Interaction: warfarin 5mg + aspirin 81mg
  //    Increased risk of serious bleeding
  //    Recommendation: Monitor closely for signs of bleeding
}
