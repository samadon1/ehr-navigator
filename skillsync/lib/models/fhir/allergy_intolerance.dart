import 'fhir_resource.dart';

/// FHIR AllergyIntolerance resource - allergies and intolerances
class AllergyIntolerance extends FhirResource {
  final CodeableConcept? clinicalStatus;
  final CodeableConcept? verificationStatus;
  final String? type; // allergy | intolerance
  final List<String> category; // food | medication | environment | biologic
  final String? criticality; // low | high | unable-to-assess
  final CodeableConcept? code;
  final FhirReference patient;
  final FhirReference? encounter;
  final DateTime? onsetDateTime;
  final DateTime? recordedDate;
  final FhirReference? recorder;
  final FhirReference? asserter;
  final DateTime? lastOccurrence;
  final List<AllergyReaction> reaction;
  final List<String> note;

  AllergyIntolerance({
    required super.id,
    super.meta,
    this.clinicalStatus,
    this.verificationStatus,
    this.type,
    this.category = const [],
    this.criticality,
    this.code,
    required this.patient,
    this.encounter,
    this.onsetDateTime,
    this.recordedDate,
    this.recorder,
    this.asserter,
    this.lastOccurrence,
    this.reaction = const [],
    this.note = const [],
  }) : super(resourceType: 'AllergyIntolerance');

  factory AllergyIntolerance.fromJson(Map<String, dynamic> json) {
    return AllergyIntolerance(
      id: json['id'] as String,
      meta: json['meta'] != null
          ? FhirMeta.fromJson(json['meta'] as Map<String, dynamic>)
          : null,
      clinicalStatus: json['clinicalStatus'] != null
          ? CodeableConcept.fromJson(
              json['clinicalStatus'] as Map<String, dynamic>)
          : null,
      verificationStatus: json['verificationStatus'] != null
          ? CodeableConcept.fromJson(
              json['verificationStatus'] as Map<String, dynamic>)
          : null,
      type: json['type'] as String?,
      category: (json['category'] as List<dynamic>?)
              ?.map((c) => c as String)
              .toList() ??
          [],
      criticality: json['criticality'] as String?,
      code: json['code'] != null
          ? CodeableConcept.fromJson(json['code'] as Map<String, dynamic>)
          : null,
      patient:
          FhirReference.fromJson(json['patient'] as Map<String, dynamic>),
      encounter: json['encounter'] != null
          ? FhirReference.fromJson(json['encounter'] as Map<String, dynamic>)
          : null,
      onsetDateTime: json['onsetDateTime'] != null
          ? DateTime.tryParse(json['onsetDateTime'] as String)
          : null,
      recordedDate: json['recordedDate'] != null
          ? DateTime.tryParse(json['recordedDate'] as String)
          : null,
      recorder: json['recorder'] != null
          ? FhirReference.fromJson(json['recorder'] as Map<String, dynamic>)
          : null,
      asserter: json['asserter'] != null
          ? FhirReference.fromJson(json['asserter'] as Map<String, dynamic>)
          : null,
      lastOccurrence: json['lastOccurrence'] != null
          ? DateTime.tryParse(json['lastOccurrence'] as String)
          : null,
      reaction: (json['reaction'] as List<dynamic>?)
              ?.map((r) => AllergyReaction.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      note: (json['note'] as List<dynamic>?)
              ?.map((n) => (n as Map<String, dynamic>)['text'] as String? ?? '')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'resourceType': resourceType,
        'id': id,
        if (meta != null) 'meta': meta!.toJson(),
        if (clinicalStatus != null) 'clinicalStatus': clinicalStatus!.toJson(),
        if (verificationStatus != null)
          'verificationStatus': verificationStatus!.toJson(),
        if (type != null) 'type': type,
        if (category.isNotEmpty) 'category': category,
        if (criticality != null) 'criticality': criticality,
        if (code != null) 'code': code!.toJson(),
        'patient': patient.toJson(),
        if (encounter != null) 'encounter': encounter!.toJson(),
        if (onsetDateTime != null)
          'onsetDateTime': onsetDateTime!.toIso8601String(),
        if (recordedDate != null)
          'recordedDate': recordedDate!.toIso8601String(),
        if (recorder != null) 'recorder': recorder!.toJson(),
        if (asserter != null) 'asserter': asserter!.toJson(),
        if (lastOccurrence != null)
          'lastOccurrence': lastOccurrence!.toIso8601String(),
        if (reaction.isNotEmpty)
          'reaction': reaction.map((r) => r.toJson()).toList(),
        if (note.isNotEmpty)
          'note': note.map((n) => {'text': n}).toList(),
      };

  @override
  String get displaySummary {
    final allergenName = code?.display ?? 'Unknown allergen';
    final criticalityDisplay = criticality == 'high' ? ' (HIGH)' : '';
    return '$allergenName$criticalityDisplay';
  }

  /// Get the name of the allergen
  String get allergenName => code?.display ?? 'Unknown allergen';

  /// Check if allergy is currently active
  bool get isActive {
    final status = clinicalStatus?.coding.firstOrNull?.code;
    return status == 'active';
  }

  /// Check if this is a medication allergy
  bool get isMedicationAllergy => category.contains('medication');

  /// Check if this is a food allergy
  bool get isFoodAllergy => category.contains('food');

  /// Check if this is high criticality
  bool get isHighCriticality => criticality == 'high';

  /// Get patient ID from patient reference
  String? get patientId => patient.resourceId;

  /// Get RxNorm code if this is a medication allergy
  String? get rxNormCode {
    return code?.coding
        .where((c) => c.system?.contains('rxnorm') == true)
        .firstOrNull
        ?.code;
  }

  /// Get SNOMED code if available
  String? get snomedCode {
    return code?.coding
        .where((c) => c.system?.contains('snomed') == true)
        .firstOrNull
        ?.code;
  }

  /// Get all manifestations from reactions
  List<String> get manifestations {
    return reaction
        .expand((r) => r.manifestation.map((m) => m.display))
        .toList();
  }
}

/// Reaction to the allergy/intolerance
class AllergyReaction {
  final CodeableConcept? substance;
  final List<CodeableConcept> manifestation;
  final String? description;
  final DateTime? onset;
  final String? severity; // mild | moderate | severe
  final CodeableConcept? exposureRoute;
  final List<String> note;

  AllergyReaction({
    this.substance,
    this.manifestation = const [],
    this.description,
    this.onset,
    this.severity,
    this.exposureRoute,
    this.note = const [],
  });

  factory AllergyReaction.fromJson(Map<String, dynamic> json) {
    return AllergyReaction(
      substance: json['substance'] != null
          ? CodeableConcept.fromJson(json['substance'] as Map<String, dynamic>)
          : null,
      manifestation: (json['manifestation'] as List<dynamic>?)
              ?.map((m) => CodeableConcept.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      description: json['description'] as String?,
      onset: json['onset'] != null
          ? DateTime.tryParse(json['onset'] as String)
          : null,
      severity: json['severity'] as String?,
      exposureRoute: json['exposureRoute'] != null
          ? CodeableConcept.fromJson(
              json['exposureRoute'] as Map<String, dynamic>)
          : null,
      note: (json['note'] as List<dynamic>?)
              ?.map((n) => (n as Map<String, dynamic>)['text'] as String? ?? '')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        if (substance != null) 'substance': substance!.toJson(),
        if (manifestation.isNotEmpty)
          'manifestation': manifestation.map((m) => m.toJson()).toList(),
        if (description != null) 'description': description,
        if (onset != null) 'onset': onset!.toIso8601String(),
        if (severity != null) 'severity': severity,
        if (exposureRoute != null) 'exposureRoute': exposureRoute!.toJson(),
        if (note.isNotEmpty)
          'note': note.map((n) => {'text': n}).toList(),
      };

  /// Get manifestations as a comma-separated string
  String get manifestationDisplay =>
      manifestation.map((m) => m.display).join(', ');

  /// Check if this is a severe reaction
  bool get isSevere => severity == 'severe';
}
