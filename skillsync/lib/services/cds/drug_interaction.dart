import '../../models/agent/cds_alert.dart';

/// Drug interaction severity
enum InteractionSeverity {
  mild,
  moderate,
  severe,
}

/// A drug interaction rule
class DrugInteraction {
  final String drug1;
  final String drug2;
  final List<String> drug1Codes;
  final List<String> drug2Codes;
  final InteractionSeverity severity;
  final String description;
  final String mechanism;
  final String recommendation;

  const DrugInteraction({
    required this.drug1,
    required this.drug2,
    this.drug1Codes = const [],
    this.drug2Codes = const [],
    required this.severity,
    required this.description,
    required this.mechanism,
    required this.recommendation,
  });
}

/// Checker for drug-drug interactions
class DrugInteractionChecker {
  /// Database of known drug interactions
  /// In production, this would be loaded from a proper drug database
  static const List<DrugInteraction> _interactions = [
    // Warfarin interactions
    DrugInteraction(
      drug1: 'warfarin',
      drug2: 'aspirin',
      drug1Codes: ['855332', '855318', '855326'], // Warfarin RxNorm codes
      drug2Codes: ['243670', '198467', '198466'], // Aspirin RxNorm codes
      severity: InteractionSeverity.severe,
      description: 'Increased risk of serious bleeding',
      mechanism: 'Both drugs have anticoagulant/antiplatelet effects',
      recommendation:
          'Monitor closely for signs of bleeding. Consider alternative therapy if possible.',
    ),
    DrugInteraction(
      drug1: 'warfarin',
      drug2: 'ibuprofen',
      drug1Codes: ['855332', '855318', '855326'],
      drug2Codes: ['197803', '197804', '197805'],
      severity: InteractionSeverity.severe,
      description: 'Increased risk of GI bleeding',
      mechanism:
          'NSAIDs inhibit platelet function and may cause GI ulceration',
      recommendation: 'Avoid concurrent use. Consider acetaminophen for pain.',
    ),
    DrugInteraction(
      drug1: 'warfarin',
      drug2: 'amiodarone',
      drug1Codes: ['855332', '855318', '855326'],
      drug2Codes: ['835719', '835711', '835715'],
      severity: InteractionSeverity.severe,
      description: 'Significantly increased warfarin effect',
      mechanism: 'Amiodarone inhibits warfarin metabolism (CYP2C9)',
      recommendation: 'Reduce warfarin dose by 30-50%. Monitor INR closely.',
    ),

    // Metformin interactions
    DrugInteraction(
      drug1: 'metformin',
      drug2: 'contrast dye',
      drug1Codes: ['860975', '860978', '860981'],
      drug2Codes: ['contrast', 'iodinated'],
      severity: InteractionSeverity.severe,
      description: 'Risk of lactic acidosis',
      mechanism:
          'Contrast-induced nephropathy can impair metformin clearance',
      recommendation:
          'Hold metformin 48h before and after contrast. Check renal function.',
    ),
    DrugInteraction(
      drug1: 'metformin',
      drug2: 'alcohol',
      drug1Codes: ['860975', '860978', '860981'],
      drug2Codes: ['alcohol', 'ethanol'],
      severity: InteractionSeverity.moderate,
      description: 'Increased risk of lactic acidosis',
      mechanism: 'Alcohol potentiates metformin effect on lactate metabolism',
      recommendation: 'Limit alcohol consumption.',
    ),

    // ACE inhibitor + potassium
    DrugInteraction(
      drug1: 'lisinopril',
      drug2: 'potassium',
      drug1Codes: ['314076', '314077', '314078'],
      drug2Codes: ['8591', 'potassium chloride'],
      severity: InteractionSeverity.moderate,
      description: 'Risk of hyperkalemia',
      mechanism: 'ACE inhibitors reduce potassium excretion',
      recommendation: 'Monitor serum potassium levels regularly.',
    ),
    DrugInteraction(
      drug1: 'lisinopril',
      drug2: 'spironolactone',
      drug1Codes: ['314076', '314077', '314078'],
      drug2Codes: ['9997', '198222', '198223'],
      severity: InteractionSeverity.severe,
      description: 'High risk of life-threatening hyperkalemia',
      mechanism: 'Both drugs cause potassium retention',
      recommendation:
          'Use with extreme caution. Monitor potassium frequently.',
    ),

    // Statin interactions
    DrugInteraction(
      drug1: 'simvastatin',
      drug2: 'amiodarone',
      drug1Codes: ['36567', '314231', '314232'],
      drug2Codes: ['835719', '835711', '835715'],
      severity: InteractionSeverity.severe,
      description: 'Increased risk of rhabdomyolysis',
      mechanism: 'Amiodarone inhibits simvastatin metabolism (CYP3A4)',
      recommendation:
          'Limit simvastatin to 20mg/day or switch to pravastatin.',
    ),
    DrugInteraction(
      drug1: 'atorvastatin',
      drug2: 'clarithromycin',
      drug1Codes: ['83367', '617318', '617319'],
      drug2Codes: ['21212', '197517', '197518'],
      severity: InteractionSeverity.moderate,
      description: 'Increased statin exposure and myopathy risk',
      mechanism: 'Clarithromycin inhibits atorvastatin metabolism (CYP3A4)',
      recommendation: 'Consider temporary statin suspension or dose reduction.',
    ),

    // Opioid interactions
    DrugInteraction(
      drug1: 'oxycodone',
      drug2: 'benzodiazepine',
      drug1Codes: ['7804', '1049621', '1049623'],
      drug2Codes: ['4501', '596', '104894'],
      severity: InteractionSeverity.severe,
      description: 'Risk of profound sedation, respiratory depression, death',
      mechanism: 'Additive CNS depression',
      recommendation:
          'Avoid concurrent use if possible. If necessary, use lowest effective doses.',
    ),

    // Antidepressant interactions
    DrugInteraction(
      drug1: 'sertraline',
      drug2: 'tramadol',
      drug1Codes: ['36437', '312940', '312941'],
      drug2Codes: ['10689', '835603', '835604'],
      severity: InteractionSeverity.severe,
      description: 'Risk of serotonin syndrome and seizures',
      mechanism: 'Both increase serotonin; tramadol lowers seizure threshold',
      recommendation:
          'Avoid concurrent use. Choose alternative pain management.',
    ),
    DrugInteraction(
      drug1: 'fluoxetine',
      drug2: 'MAO inhibitor',
      drug1Codes: ['4493', '310384', '310385'],
      drug2Codes: ['6011', '6012', 'phenelzine', 'tranylcypromine'],
      severity: InteractionSeverity.severe,
      description: 'Life-threatening serotonin syndrome',
      mechanism: 'Massive serotonin accumulation',
      recommendation:
          'CONTRAINDICATED. Allow 5-week washout between these drugs.',
    ),

    // Cardiac drug interactions
    DrugInteraction(
      drug1: 'digoxin',
      drug2: 'amiodarone',
      drug1Codes: ['3407', '197604', '197605'],
      drug2Codes: ['835719', '835711', '835715'],
      severity: InteractionSeverity.severe,
      description: 'Digoxin toxicity',
      mechanism: 'Amiodarone reduces digoxin clearance',
      recommendation: 'Reduce digoxin dose by 50%. Monitor digoxin levels.',
    ),
    DrugInteraction(
      drug1: 'digoxin',
      drug2: 'verapamil',
      drug1Codes: ['3407', '197604', '197605'],
      drug2Codes: ['11170', '897718', '897719'],
      severity: InteractionSeverity.moderate,
      description: 'Increased digoxin levels and bradycardia',
      mechanism: 'Verapamil inhibits P-glycoprotein',
      recommendation: 'Reduce digoxin dose. Monitor heart rate and rhythm.',
    ),

    // Antibiotic interactions
    DrugInteraction(
      drug1: 'fluoroquinolone',
      drug2: 'theophylline',
      drug1Codes: ['2551', '82122', 'ciprofloxacin', 'levofloxacin'],
      drug2Codes: ['10438', '198334', '198335'],
      severity: InteractionSeverity.moderate,
      description: 'Increased theophylline toxicity',
      mechanism: 'Fluoroquinolones inhibit theophylline metabolism',
      recommendation: 'Monitor theophylline levels. Consider dose adjustment.',
    ),
  ];

  /// Check for drug interactions in a medication list
  Future<List<CdsAlert>> check({
    required List<Map<String, dynamic>> medications,
    List<Map<String, dynamic>>? allergies,
    String? proposedMedication,
  }) async {
    final alerts = <CdsAlert>[];

    // Get medication names and codes
    final medList = <({String name, String? code})>[];
    for (final med in medications) {
      final name = (med['name'] as String? ?? '').toLowerCase();
      final code = med['rxNormCode'] as String?;
      medList.add((name: name, code: code));
    }

    // Add proposed medication if provided
    if (proposedMedication != null) {
      medList.add((name: proposedMedication.toLowerCase(), code: null));
    }

    // Check all pairs
    for (var i = 0; i < medList.length; i++) {
      for (var j = i + 1; j < medList.length; j++) {
        final interaction = _findInteraction(medList[i], medList[j]);
        if (interaction != null) {
          alerts.add(_createAlert(
            interaction,
            medList[i].name,
            medList[j].name,
          ));
        }
      }
    }

    return alerts;
  }

  /// Find an interaction between two medications
  DrugInteraction? _findInteraction(
    ({String name, String? code}) med1,
    ({String name, String? code}) med2,
  ) {
    for (final interaction in _interactions) {
      if (_matchesDrug(med1, interaction.drug1, interaction.drug1Codes) &&
          _matchesDrug(med2, interaction.drug2, interaction.drug2Codes)) {
        return interaction;
      }
      // Check reverse order
      if (_matchesDrug(med1, interaction.drug2, interaction.drug2Codes) &&
          _matchesDrug(med2, interaction.drug1, interaction.drug1Codes)) {
        return interaction;
      }
    }
    return null;
  }

  /// Check if a medication matches a drug in the interaction database
  bool _matchesDrug(
    ({String name, String? code}) med,
    String drugName,
    List<String> drugCodes,
  ) {
    // Check by code
    if (med.code != null && drugCodes.contains(med.code)) {
      return true;
    }

    // Check by name (partial match)
    final nameLower = drugName.toLowerCase();
    if (med.name.contains(nameLower) || nameLower.contains(med.name)) {
      return true;
    }

    // Check if drug codes list contains partial name matches
    for (final code in drugCodes) {
      if (med.name.contains(code.toLowerCase())) {
        return true;
      }
    }

    return false;
  }

  /// Create an alert from an interaction
  CdsAlert _createAlert(
    DrugInteraction interaction,
    String med1Name,
    String med2Name,
  ) {
    final severity = switch (interaction.severity) {
      InteractionSeverity.severe => CdsSeverity.critical,
      InteractionSeverity.moderate => CdsSeverity.high,
      InteractionSeverity.mild => CdsSeverity.moderate,
    };

    return CdsAlert(
      type: CdsAlertType.drugInteraction,
      severity: severity,
      title: 'Drug Interaction: $med1Name + $med2Name',
      description: interaction.description,
      recommendations: [
        interaction.recommendation,
        'Mechanism: ${interaction.mechanism}',
      ],
      context: {
        'drug1': med1Name,
        'drug2': med2Name,
        'interactionType': interaction.severity.name,
      },
    );
  }
}
