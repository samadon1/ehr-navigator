import 'fhir_resource.dart';

/// FHIR Encounter resource - a patient visit or interaction
class Encounter extends FhirResource {
  final String status; // planned | arrived | triaged | in-progress | onleave | finished | cancelled | entered-in-error | unknown
  final Coding? encounterClass; // inpatient | outpatient | ambulatory | emergency | home | field | daytime | virtual | other
  final List<CodeableConcept> type;
  final CodeableConcept? serviceType;
  final CodeableConcept? priority;
  final FhirReference subject;
  final FhirPeriod? period;
  final List<CodeableConcept> reasonCode;
  final List<FhirReference> reasonReference;
  final List<EncounterDiagnosis> diagnosis;
  final List<EncounterParticipant> participant;
  final FhirReference? serviceProvider;

  Encounter({
    required super.id,
    super.meta,
    required this.status,
    this.encounterClass,
    this.type = const [],
    this.serviceType,
    this.priority,
    required this.subject,
    this.period,
    this.reasonCode = const [],
    this.reasonReference = const [],
    this.diagnosis = const [],
    this.participant = const [],
    this.serviceProvider,
  }) : super(resourceType: 'Encounter');

  factory Encounter.fromJson(Map<String, dynamic> json) {
    return Encounter(
      id: json['id'] as String,
      meta: json['meta'] != null
          ? FhirMeta.fromJson(json['meta'] as Map<String, dynamic>)
          : null,
      status: json['status'] as String,
      encounterClass: json['class'] != null
          ? Coding.fromJson(json['class'] as Map<String, dynamic>)
          : null,
      type: (json['type'] as List<dynamic>?)
              ?.map((t) => CodeableConcept.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      serviceType: json['serviceType'] != null
          ? CodeableConcept.fromJson(
              json['serviceType'] as Map<String, dynamic>)
          : null,
      priority: json['priority'] != null
          ? CodeableConcept.fromJson(json['priority'] as Map<String, dynamic>)
          : null,
      subject:
          FhirReference.fromJson(json['subject'] as Map<String, dynamic>),
      period: json['period'] != null
          ? FhirPeriod.fromJson(json['period'] as Map<String, dynamic>)
          : null,
      reasonCode: (json['reasonCode'] as List<dynamic>?)
              ?.map((r) => CodeableConcept.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      reasonReference: (json['reasonReference'] as List<dynamic>?)
              ?.map((r) => FhirReference.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      diagnosis: (json['diagnosis'] as List<dynamic>?)
              ?.map(
                  (d) => EncounterDiagnosis.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      participant: (json['participant'] as List<dynamic>?)
              ?.map((p) =>
                  EncounterParticipant.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      serviceProvider: json['serviceProvider'] != null
          ? FhirReference.fromJson(
              json['serviceProvider'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'resourceType': resourceType,
        'id': id,
        if (meta != null) 'meta': meta!.toJson(),
        'status': status,
        if (encounterClass != null) 'class': encounterClass!.toJson(),
        if (type.isNotEmpty) 'type': type.map((t) => t.toJson()).toList(),
        if (serviceType != null) 'serviceType': serviceType!.toJson(),
        if (priority != null) 'priority': priority!.toJson(),
        'subject': subject.toJson(),
        if (period != null) 'period': period!.toJson(),
        if (reasonCode.isNotEmpty)
          'reasonCode': reasonCode.map((r) => r.toJson()).toList(),
        if (reasonReference.isNotEmpty)
          'reasonReference': reasonReference.map((r) => r.toJson()).toList(),
        if (diagnosis.isNotEmpty)
          'diagnosis': diagnosis.map((d) => d.toJson()).toList(),
        if (participant.isNotEmpty)
          'participant': participant.map((p) => p.toJson()).toList(),
        if (serviceProvider != null)
          'serviceProvider': serviceProvider!.toJson(),
      };

  @override
  String get displaySummary {
    final typeDisplay = type.isNotEmpty
        ? type.first.display
        : encounterClass?.display ?? 'Visit';
    final dateDisplay = period?.start != null
        ? '${period!.start!.year}-${period!.start!.month.toString().padLeft(2, '0')}-${period!.start!.day.toString().padLeft(2, '0')}'
        : 'Unknown date';
    return '$typeDisplay ($dateDisplay)';
  }

  /// Get the encounter class as a display string
  String get classDisplay => encounterClass?.display ?? 'Unknown';

  /// Check if encounter is active
  bool get isActive =>
      status == 'in-progress' ||
      status == 'arrived' ||
      status == 'triaged' ||
      status == 'onleave';

  /// Check if encounter is finished
  bool get isFinished => status == 'finished';

  /// Get patient ID from subject reference
  String? get patientId => subject.resourceId;

  /// Get primary reason for visit
  String? get primaryReason {
    if (reasonCode.isNotEmpty) return reasonCode.first.display;
    return null;
  }

  /// Get encounter duration in hours (if period is available)
  double? get durationHours {
    if (period?.start == null || period?.end == null) return null;
    return period!.end!.difference(period!.start!).inMinutes / 60.0;
  }
}

/// Diagnosis associated with an encounter
class EncounterDiagnosis {
  final FhirReference condition;
  final CodeableConcept? use;
  final int? rank;

  EncounterDiagnosis({
    required this.condition,
    this.use,
    this.rank,
  });

  factory EncounterDiagnosis.fromJson(Map<String, dynamic> json) {
    return EncounterDiagnosis(
      condition:
          FhirReference.fromJson(json['condition'] as Map<String, dynamic>),
      use: json['use'] != null
          ? CodeableConcept.fromJson(json['use'] as Map<String, dynamic>)
          : null,
      rank: json['rank'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'condition': condition.toJson(),
        if (use != null) 'use': use!.toJson(),
        if (rank != null) 'rank': rank,
      };
}

/// Participant in an encounter
class EncounterParticipant {
  final List<CodeableConcept> type;
  final FhirPeriod? period;
  final FhirReference? individual;

  EncounterParticipant({
    this.type = const [],
    this.period,
    this.individual,
  });

  factory EncounterParticipant.fromJson(Map<String, dynamic> json) {
    return EncounterParticipant(
      type: (json['type'] as List<dynamic>?)
              ?.map((t) => CodeableConcept.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      period: json['period'] != null
          ? FhirPeriod.fromJson(json['period'] as Map<String, dynamic>)
          : null,
      individual: json['individual'] != null
          ? FhirReference.fromJson(json['individual'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (type.isNotEmpty) 'type': type.map((t) => t.toJson()).toList(),
        if (period != null) 'period': period!.toJson(),
        if (individual != null) 'individual': individual!.toJson(),
      };
}
