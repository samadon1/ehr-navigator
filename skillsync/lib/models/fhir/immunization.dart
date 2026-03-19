import 'fhir_resource.dart';

/// FHIR Immunization resource - vaccination records
class Immunization extends FhirResource {
  final String status; // completed | entered-in-error | not-done
  final CodeableConcept vaccineCode;
  final FhirReference patient;
  final FhirReference? encounter;
  final DateTime? occurrenceDateTime;
  final String? occurrenceString;
  final DateTime? recorded;
  final bool? primarySource;
  final CodeableConcept? site;
  final CodeableConcept? route;
  final Quantity? doseQuantity;
  final List<ImmunizationPerformer> performer;
  final String? lotNumber;
  final DateTime? expirationDate;
  final List<CodeableConcept> reasonCode;

  Immunization({
    required super.id,
    super.meta,
    required this.status,
    required this.vaccineCode,
    required this.patient,
    this.encounter,
    this.occurrenceDateTime,
    this.occurrenceString,
    this.recorded,
    this.primarySource,
    this.site,
    this.route,
    this.doseQuantity,
    this.performer = const [],
    this.lotNumber,
    this.expirationDate,
    this.reasonCode = const [],
  }) : super(resourceType: 'Immunization');

  factory Immunization.fromJson(Map<String, dynamic> json) {
    return Immunization(
      id: json['id'] as String,
      meta: json['meta'] != null
          ? FhirMeta.fromJson(json['meta'] as Map<String, dynamic>)
          : null,
      status: json['status'] as String,
      vaccineCode:
          CodeableConcept.fromJson(json['vaccineCode'] as Map<String, dynamic>),
      patient: FhirReference.fromJson(json['patient'] as Map<String, dynamic>),
      encounter: json['encounter'] != null
          ? FhirReference.fromJson(json['encounter'] as Map<String, dynamic>)
          : null,
      occurrenceDateTime: json['occurrenceDateTime'] != null
          ? DateTime.tryParse(json['occurrenceDateTime'] as String)
          : null,
      occurrenceString: json['occurrenceString'] as String?,
      recorded: json['recorded'] != null
          ? DateTime.tryParse(json['recorded'] as String)
          : null,
      primarySource: json['primarySource'] as bool?,
      site: json['site'] != null
          ? CodeableConcept.fromJson(json['site'] as Map<String, dynamic>)
          : null,
      route: json['route'] != null
          ? CodeableConcept.fromJson(json['route'] as Map<String, dynamic>)
          : null,
      doseQuantity: json['doseQuantity'] != null
          ? Quantity.fromJson(json['doseQuantity'] as Map<String, dynamic>)
          : null,
      performer: (json['performer'] as List<dynamic>?)
              ?.map((p) =>
                  ImmunizationPerformer.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      lotNumber: json['lotNumber'] as String?,
      expirationDate: json['expirationDate'] != null
          ? DateTime.tryParse(json['expirationDate'] as String)
          : null,
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
        'vaccineCode': vaccineCode.toJson(),
        'patient': patient.toJson(),
        if (encounter != null) 'encounter': encounter!.toJson(),
        if (occurrenceDateTime != null)
          'occurrenceDateTime': occurrenceDateTime!.toIso8601String(),
        if (occurrenceString != null) 'occurrenceString': occurrenceString,
        if (recorded != null) 'recorded': recorded!.toIso8601String(),
        if (primarySource != null) 'primarySource': primarySource,
        if (site != null) 'site': site!.toJson(),
        if (route != null) 'route': route!.toJson(),
        if (doseQuantity != null) 'doseQuantity': doseQuantity!.toJson(),
        if (performer.isNotEmpty)
          'performer': performer.map((p) => p.toJson()).toList(),
        if (lotNumber != null) 'lotNumber': lotNumber,
        if (expirationDate != null)
          'expirationDate': expirationDate!.toIso8601String(),
        if (reasonCode.isNotEmpty)
          'reasonCode': reasonCode.map((c) => c.toJson()).toList(),
      };

  @override
  String get displaySummary => '${vaccineCode.display} (${status})';

  /// Get CVX code if available
  String? get cvxCode {
    return vaccineCode.coding
        .where((c) => c.system?.contains('cvx') == true)
        .firstOrNull
        ?.code;
  }

  /// Get patient ID from patient reference
  String? get patientId => patient.resourceId;

  /// Check if immunization was completed
  bool get isCompleted => status == 'completed';
}

/// Performer of the immunization
class ImmunizationPerformer {
  final CodeableConcept? function;
  final FhirReference actor;

  ImmunizationPerformer({
    this.function,
    required this.actor,
  });

  factory ImmunizationPerformer.fromJson(Map<String, dynamic> json) {
    return ImmunizationPerformer(
      function: json['function'] != null
          ? CodeableConcept.fromJson(json['function'] as Map<String, dynamic>)
          : null,
      actor: FhirReference.fromJson(json['actor'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        if (function != null) 'function': function!.toJson(),
        'actor': actor.toJson(),
      };
}
