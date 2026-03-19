import 'fhir_resource.dart';

/// FHIR MedicationStatement resource - records of medication being taken
class MedicationStatement extends FhirResource {
  final String status; // active | completed | entered-in-error | intended | stopped | on-hold | unknown | not-taken
  final CodeableConcept? statusReason;
  final CodeableConcept? medicationCodeableConcept;
  final FhirReference? medicationReference;
  final FhirReference subject;
  final FhirReference? context;
  final DateTime? effectiveDateTime;
  final FhirPeriod? effectivePeriod;
  final DateTime? dateAsserted;
  final List<Dosage> dosage;
  final List<FhirReference> reasonReference;
  final List<CodeableConcept> reasonCode;

  MedicationStatement({
    required super.id,
    super.meta,
    required this.status,
    this.statusReason,
    this.medicationCodeableConcept,
    this.medicationReference,
    required this.subject,
    this.context,
    this.effectiveDateTime,
    this.effectivePeriod,
    this.dateAsserted,
    this.dosage = const [],
    this.reasonReference = const [],
    this.reasonCode = const [],
  }) : super(resourceType: 'MedicationStatement');

  factory MedicationStatement.fromJson(Map<String, dynamic> json) {
    return MedicationStatement(
      id: json['id'] as String,
      meta: json['meta'] != null
          ? FhirMeta.fromJson(json['meta'] as Map<String, dynamic>)
          : null,
      status: json['status'] as String,
      statusReason: json['statusReason'] != null
          ? CodeableConcept.fromJson(
              json['statusReason'] as Map<String, dynamic>)
          : null,
      medicationCodeableConcept: json['medicationCodeableConcept'] != null
          ? CodeableConcept.fromJson(
              json['medicationCodeableConcept'] as Map<String, dynamic>)
          : null,
      medicationReference: json['medicationReference'] != null
          ? FhirReference.fromJson(
              json['medicationReference'] as Map<String, dynamic>)
          : null,
      subject:
          FhirReference.fromJson(json['subject'] as Map<String, dynamic>),
      context: json['context'] != null
          ? FhirReference.fromJson(json['context'] as Map<String, dynamic>)
          : null,
      effectiveDateTime: json['effectiveDateTime'] != null
          ? DateTime.tryParse(json['effectiveDateTime'] as String)
          : null,
      effectivePeriod: json['effectivePeriod'] != null
          ? FhirPeriod.fromJson(json['effectivePeriod'] as Map<String, dynamic>)
          : null,
      dateAsserted: json['dateAsserted'] != null
          ? DateTime.tryParse(json['dateAsserted'] as String)
          : null,
      dosage: (json['dosage'] as List<dynamic>?)
              ?.map((d) => Dosage.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      reasonReference: (json['reasonReference'] as List<dynamic>?)
              ?.map((r) => FhirReference.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      reasonCode: (json['reasonCode'] as List<dynamic>?)
              ?.map((c) => CodeableConcept.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'resourceType': resourceType,
        'id': id,
        if (meta != null) 'meta': meta!.toJson(),
        'status': status,
        if (statusReason != null) 'statusReason': statusReason!.toJson(),
        if (medicationCodeableConcept != null)
          'medicationCodeableConcept': medicationCodeableConcept!.toJson(),
        if (medicationReference != null)
          'medicationReference': medicationReference!.toJson(),
        'subject': subject.toJson(),
        if (context != null) 'context': context!.toJson(),
        if (effectiveDateTime != null)
          'effectiveDateTime': effectiveDateTime!.toIso8601String(),
        if (effectivePeriod != null)
          'effectivePeriod': effectivePeriod!.toJson(),
        if (dateAsserted != null)
          'dateAsserted': dateAsserted!.toIso8601String(),
        if (dosage.isNotEmpty)
          'dosage': dosage.map((d) => d.toJson()).toList(),
        if (reasonReference.isNotEmpty)
          'reasonReference': reasonReference.map((r) => r.toJson()).toList(),
        if (reasonCode.isNotEmpty)
          'reasonCode': reasonCode.map((c) => c.toJson()).toList(),
      };

  @override
  String get displaySummary => medicationName;

  /// Get the medication name
  String get medicationName =>
      medicationCodeableConcept?.display ??
      medicationReference?.display ??
      'Unknown Medication';

  /// Get RxNorm code if available
  String? get rxNormCode {
    return medicationCodeableConcept?.coding
        .where((c) => c.system?.contains('rxnorm') == true)
        .firstOrNull
        ?.code;
  }

  /// Check if medication is currently active
  bool get isActive => status == 'active';

  /// Get patient ID from subject reference
  String? get patientId => subject.resourceId;

  /// Get dosage instructions as a string
  String get dosageInstructions {
    if (dosage.isEmpty) return 'No dosage information';
    return dosage.map((d) => d.text ?? d.display).join('; ');
  }
}

/// FHIR MedicationRequest resource - an order/prescription for medication
class MedicationRequest extends FhirResource {
  final String status; // active | on-hold | cancelled | completed | entered-in-error | stopped | draft | unknown
  final String intent; // proposal | plan | order | original-order | reflex-order | filler-order | instance-order | option
  final CodeableConcept? medicationCodeableConcept;
  final FhirReference? medicationReference;
  final FhirReference subject;
  final FhirReference? encounter;
  final DateTime? authoredOn;
  final FhirReference? requester;
  final List<Dosage> dosageInstruction;
  final List<CodeableConcept> reasonCode;
  final List<FhirReference> reasonReference;

  MedicationRequest({
    required super.id,
    super.meta,
    required this.status,
    required this.intent,
    this.medicationCodeableConcept,
    this.medicationReference,
    required this.subject,
    this.encounter,
    this.authoredOn,
    this.requester,
    this.dosageInstruction = const [],
    this.reasonCode = const [],
    this.reasonReference = const [],
  }) : super(resourceType: 'MedicationRequest');

  factory MedicationRequest.fromJson(Map<String, dynamic> json) {
    return MedicationRequest(
      id: json['id'] as String,
      meta: json['meta'] != null
          ? FhirMeta.fromJson(json['meta'] as Map<String, dynamic>)
          : null,
      status: json['status'] as String,
      intent: json['intent'] as String,
      medicationCodeableConcept: json['medicationCodeableConcept'] != null
          ? CodeableConcept.fromJson(
              json['medicationCodeableConcept'] as Map<String, dynamic>)
          : null,
      medicationReference: json['medicationReference'] != null
          ? FhirReference.fromJson(
              json['medicationReference'] as Map<String, dynamic>)
          : null,
      subject:
          FhirReference.fromJson(json['subject'] as Map<String, dynamic>),
      encounter: json['encounter'] != null
          ? FhirReference.fromJson(json['encounter'] as Map<String, dynamic>)
          : null,
      authoredOn: json['authoredOn'] != null
          ? DateTime.tryParse(json['authoredOn'] as String)
          : null,
      requester: json['requester'] != null
          ? FhirReference.fromJson(json['requester'] as Map<String, dynamic>)
          : null,
      dosageInstruction: (json['dosageInstruction'] as List<dynamic>?)
              ?.map((d) => Dosage.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      reasonCode: (json['reasonCode'] as List<dynamic>?)
              ?.map((c) => CodeableConcept.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      reasonReference: (json['reasonReference'] as List<dynamic>?)
              ?.map((r) => FhirReference.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'resourceType': resourceType,
        'id': id,
        if (meta != null) 'meta': meta!.toJson(),
        'status': status,
        'intent': intent,
        if (medicationCodeableConcept != null)
          'medicationCodeableConcept': medicationCodeableConcept!.toJson(),
        if (medicationReference != null)
          'medicationReference': medicationReference!.toJson(),
        'subject': subject.toJson(),
        if (encounter != null) 'encounter': encounter!.toJson(),
        if (authoredOn != null) 'authoredOn': authoredOn!.toIso8601String(),
        if (requester != null) 'requester': requester!.toJson(),
        if (dosageInstruction.isNotEmpty)
          'dosageInstruction':
              dosageInstruction.map((d) => d.toJson()).toList(),
        if (reasonCode.isNotEmpty)
          'reasonCode': reasonCode.map((c) => c.toJson()).toList(),
        if (reasonReference.isNotEmpty)
          'reasonReference': reasonReference.map((r) => r.toJson()).toList(),
      };

  @override
  String get displaySummary => medicationName;

  /// Get the medication name
  String get medicationName =>
      medicationCodeableConcept?.display ??
      medicationReference?.display ??
      'Unknown Medication';

  /// Get RxNorm code if available
  String? get rxNormCode {
    return medicationCodeableConcept?.coding
        .where((c) => c.system?.contains('rxnorm') == true)
        .firstOrNull
        ?.code;
  }

  /// Check if prescription is currently active
  bool get isActive => status == 'active';

  /// Get patient ID from subject reference
  String? get patientId => subject.resourceId;
}

/// FHIR Dosage element
class Dosage {
  final int? sequence;
  final String? text;
  final CodeableConcept? timing;
  final bool? asNeededBoolean;
  final CodeableConcept? site;
  final CodeableConcept? route;
  final CodeableConcept? method;
  final Quantity? doseQuantity;
  final Quantity? maxDosePerPeriod;

  Dosage({
    this.sequence,
    this.text,
    this.timing,
    this.asNeededBoolean,
    this.site,
    this.route,
    this.method,
    this.doseQuantity,
    this.maxDosePerPeriod,
  });

  factory Dosage.fromJson(Map<String, dynamic> json) {
    // Handle doseAndRate array format
    Quantity? doseQty;
    if (json['doseAndRate'] != null) {
      final doseAndRate = json['doseAndRate'] as List<dynamic>;
      if (doseAndRate.isNotEmpty) {
        final first = doseAndRate.first as Map<String, dynamic>;
        if (first['doseQuantity'] != null) {
          doseQty = Quantity.fromJson(first['doseQuantity'] as Map<String, dynamic>);
        }
      }
    } else if (json['doseQuantity'] != null) {
      doseQty = Quantity.fromJson(json['doseQuantity'] as Map<String, dynamic>);
    }

    return Dosage(
      sequence: json['sequence'] as int?,
      text: json['text'] as String?,
      timing: json['timing'] != null
          ? CodeableConcept.fromJson(json['timing'] as Map<String, dynamic>)
          : null,
      asNeededBoolean: json['asNeededBoolean'] as bool?,
      site: json['site'] != null
          ? CodeableConcept.fromJson(json['site'] as Map<String, dynamic>)
          : null,
      route: json['route'] != null
          ? CodeableConcept.fromJson(json['route'] as Map<String, dynamic>)
          : null,
      method: json['method'] != null
          ? CodeableConcept.fromJson(json['method'] as Map<String, dynamic>)
          : null,
      doseQuantity: doseQty,
      maxDosePerPeriod: json['maxDosePerPeriod'] != null
          ? Quantity.fromJson(json['maxDosePerPeriod'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (sequence != null) 'sequence': sequence,
        if (text != null) 'text': text,
        if (timing != null) 'timing': timing!.toJson(),
        if (asNeededBoolean != null) 'asNeededBoolean': asNeededBoolean,
        if (site != null) 'site': site!.toJson(),
        if (route != null) 'route': route!.toJson(),
        if (method != null) 'method': method!.toJson(),
        if (doseQuantity != null) 'doseQuantity': doseQuantity!.toJson(),
        if (maxDosePerPeriod != null)
          'maxDosePerPeriod': maxDosePerPeriod!.toJson(),
      };

  /// Get display string for dosage
  String get display {
    final parts = <String>[];
    if (doseQuantity != null) {
      parts.add(doseQuantity!.display);
    }
    if (route != null) {
      parts.add(route!.display);
    }
    if (timing != null) {
      parts.add(timing!.display);
    }
    if (asNeededBoolean == true) {
      parts.add('as needed');
    }
    return parts.isEmpty ? text ?? 'No dosage info' : parts.join(' ');
  }
}
