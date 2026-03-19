import 'fhir_resource.dart';

/// FHIR Condition resource - represents diagnoses, problems, health concerns
class Condition extends FhirResource {
  final CodeableConcept? clinicalStatus;
  final CodeableConcept? verificationStatus;
  final List<CodeableConcept> category;
  final CodeableConcept? severity;
  final CodeableConcept code;
  final FhirReference subject;
  final FhirReference? encounter;
  final DateTime? onsetDateTime;
  final DateTime? abatementDateTime;
  final DateTime? recordedDate;
  final FhirReference? recorder;
  final List<String> note;

  Condition({
    required super.id,
    super.meta,
    this.clinicalStatus,
    this.verificationStatus,
    this.category = const [],
    this.severity,
    required this.code,
    required this.subject,
    this.encounter,
    this.onsetDateTime,
    this.abatementDateTime,
    this.recordedDate,
    this.recorder,
    this.note = const [],
  }) : super(resourceType: 'Condition');

  factory Condition.fromJson(Map<String, dynamic> json) {
    return Condition(
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
      category: (json['category'] as List<dynamic>?)
              ?.map((c) => CodeableConcept.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      severity: json['severity'] != null
          ? CodeableConcept.fromJson(json['severity'] as Map<String, dynamic>)
          : null,
      code: CodeableConcept.fromJson(json['code'] as Map<String, dynamic>),
      subject:
          FhirReference.fromJson(json['subject'] as Map<String, dynamic>),
      encounter: json['encounter'] != null
          ? FhirReference.fromJson(json['encounter'] as Map<String, dynamic>)
          : null,
      onsetDateTime: json['onsetDateTime'] != null
          ? DateTime.tryParse(json['onsetDateTime'] as String)
          : null,
      abatementDateTime: json['abatementDateTime'] != null
          ? DateTime.tryParse(json['abatementDateTime'] as String)
          : null,
      recordedDate: json['recordedDate'] != null
          ? DateTime.tryParse(json['recordedDate'] as String)
          : null,
      recorder: json['recorder'] != null
          ? FhirReference.fromJson(json['recorder'] as Map<String, dynamic>)
          : null,
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
        if (category.isNotEmpty)
          'category': category.map((c) => c.toJson()).toList(),
        if (severity != null) 'severity': severity!.toJson(),
        'code': code.toJson(),
        'subject': subject.toJson(),
        if (encounter != null) 'encounter': encounter!.toJson(),
        if (onsetDateTime != null)
          'onsetDateTime': onsetDateTime!.toIso8601String(),
        if (abatementDateTime != null)
          'abatementDateTime': abatementDateTime!.toIso8601String(),
        if (recordedDate != null)
          'recordedDate': recordedDate!.toIso8601String(),
        if (recorder != null) 'recorder': recorder!.toJson(),
        if (note.isNotEmpty)
          'note': note.map((n) => {'text': n}).toList(),
      };

  @override
  String get displaySummary => code.display;

  /// Check if condition is currently active
  bool get isActive {
    final status = clinicalStatus?.coding.firstOrNull?.code;
    return status == 'active' || status == 'recurrence' || status == 'relapse';
  }

  /// Check if condition is resolved
  bool get isResolved {
    final status = clinicalStatus?.coding.firstOrNull?.code;
    return status == 'resolved' || status == 'remission';
  }

  /// Get SNOMED CT code if available
  String? get snomedCode {
    return code.coding
        .where((c) => c.system?.contains('snomed') == true)
        .firstOrNull
        ?.code;
  }

  /// Get ICD-10 code if available
  String? get icd10Code {
    return code.coding
        .where((c) => c.system?.contains('icd') == true)
        .firstOrNull
        ?.code;
  }

  /// Get patient ID from subject reference
  String? get patientId => subject.resourceId;
}
