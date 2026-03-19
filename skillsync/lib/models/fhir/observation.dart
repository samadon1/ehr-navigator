import 'fhir_resource.dart';

/// FHIR Observation resource - measurements and simple assertions
class Observation extends FhirResource {
  final String status; // registered | preliminary | final | amended | corrected | cancelled | entered-in-error | unknown
  final List<CodeableConcept> category;
  final CodeableConcept code;
  final FhirReference subject;
  final FhirReference? encounter;
  final DateTime? effectiveDateTime;
  final FhirPeriod? effectivePeriod;
  final DateTime? issued;
  final Quantity? valueQuantity;
  final CodeableConcept? valueCodeableConcept;
  final String? valueString;
  final bool? valueBoolean;
  final int? valueInteger;
  final CodeableConcept? dataAbsentReason;
  final List<CodeableConcept> interpretation;
  final List<ObservationReferenceRange> referenceRange;
  final List<ObservationComponent> component;

  Observation({
    required super.id,
    super.meta,
    required this.status,
    this.category = const [],
    required this.code,
    required this.subject,
    this.encounter,
    this.effectiveDateTime,
    this.effectivePeriod,
    this.issued,
    this.valueQuantity,
    this.valueCodeableConcept,
    this.valueString,
    this.valueBoolean,
    this.valueInteger,
    this.dataAbsentReason,
    this.interpretation = const [],
    this.referenceRange = const [],
    this.component = const [],
  }) : super(resourceType: 'Observation');

  factory Observation.fromJson(Map<String, dynamic> json) {
    return Observation(
      id: json['id'] as String,
      meta: json['meta'] != null
          ? FhirMeta.fromJson(json['meta'] as Map<String, dynamic>)
          : null,
      status: json['status'] as String,
      category: (json['category'] as List<dynamic>?)
              ?.map((c) => CodeableConcept.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      code: CodeableConcept.fromJson(json['code'] as Map<String, dynamic>),
      subject:
          FhirReference.fromJson(json['subject'] as Map<String, dynamic>),
      encounter: json['encounter'] != null
          ? FhirReference.fromJson(json['encounter'] as Map<String, dynamic>)
          : null,
      effectiveDateTime: json['effectiveDateTime'] != null
          ? DateTime.tryParse(json['effectiveDateTime'] as String)
          : null,
      effectivePeriod: json['effectivePeriod'] != null
          ? FhirPeriod.fromJson(json['effectivePeriod'] as Map<String, dynamic>)
          : null,
      issued: json['issued'] != null
          ? DateTime.tryParse(json['issued'] as String)
          : null,
      valueQuantity: json['valueQuantity'] != null
          ? Quantity.fromJson(json['valueQuantity'] as Map<String, dynamic>)
          : null,
      valueCodeableConcept: json['valueCodeableConcept'] != null
          ? CodeableConcept.fromJson(
              json['valueCodeableConcept'] as Map<String, dynamic>)
          : null,
      valueString: json['valueString'] as String?,
      valueBoolean: json['valueBoolean'] as bool?,
      valueInteger: json['valueInteger'] as int?,
      dataAbsentReason: json['dataAbsentReason'] != null
          ? CodeableConcept.fromJson(
              json['dataAbsentReason'] as Map<String, dynamic>)
          : null,
      interpretation: (json['interpretation'] as List<dynamic>?)
              ?.map((i) => CodeableConcept.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      referenceRange: (json['referenceRange'] as List<dynamic>?)
              ?.map((r) =>
                  ObservationReferenceRange.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      component: (json['component'] as List<dynamic>?)
              ?.map((c) =>
                  ObservationComponent.fromJson(c as Map<String, dynamic>))
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
        if (category.isNotEmpty)
          'category': category.map((c) => c.toJson()).toList(),
        'code': code.toJson(),
        'subject': subject.toJson(),
        if (encounter != null) 'encounter': encounter!.toJson(),
        if (effectiveDateTime != null)
          'effectiveDateTime': effectiveDateTime!.toIso8601String(),
        if (effectivePeriod != null)
          'effectivePeriod': effectivePeriod!.toJson(),
        if (issued != null) 'issued': issued!.toIso8601String(),
        if (valueQuantity != null) 'valueQuantity': valueQuantity!.toJson(),
        if (valueCodeableConcept != null)
          'valueCodeableConcept': valueCodeableConcept!.toJson(),
        if (valueString != null) 'valueString': valueString,
        if (valueBoolean != null) 'valueBoolean': valueBoolean,
        if (valueInteger != null) 'valueInteger': valueInteger,
        if (dataAbsentReason != null)
          'dataAbsentReason': dataAbsentReason!.toJson(),
        if (interpretation.isNotEmpty)
          'interpretation': interpretation.map((i) => i.toJson()).toList(),
        if (referenceRange.isNotEmpty)
          'referenceRange': referenceRange.map((r) => r.toJson()).toList(),
        if (component.isNotEmpty)
          'component': component.map((c) => c.toJson()).toList(),
      };

  @override
  String get displaySummary => '${code.display}: $valueDisplay';

  /// Get the value as a display string
  String get valueDisplay {
    if (valueQuantity != null) return valueQuantity!.display;
    if (valueCodeableConcept != null) return valueCodeableConcept!.display;
    if (valueString != null) return valueString!;
    if (valueBoolean != null) return valueBoolean! ? 'Yes' : 'No';
    if (valueInteger != null) return valueInteger.toString();
    if (dataAbsentReason != null) return 'N/A (${dataAbsentReason!.display})';
    return 'No value';
  }

  /// Get LOINC code if available
  String? get loincCode {
    return code.coding
        .where((c) => c.system?.contains('loinc') == true)
        .firstOrNull
        ?.code;
  }

  /// Get the primary category (vital-signs, laboratory, etc.)
  String? get primaryCategory {
    if (category.isEmpty) return null;
    return category.first.coding.firstOrNull?.code;
  }

  /// Check if this is a vital sign observation
  bool get isVitalSign => primaryCategory == 'vital-signs';

  /// Check if this is a laboratory observation
  bool get isLaboratory => primaryCategory == 'laboratory';

  /// Get patient ID from subject reference
  String? get patientId => subject.resourceId;

  /// Get the effective date (from either effectiveDateTime or effectivePeriod)
  DateTime? get effectiveDate =>
      effectiveDateTime ?? effectivePeriod?.start;

  /// Check if value is abnormal based on interpretation
  bool get isAbnormal {
    final interpCodes = interpretation
        .expand((i) => i.coding)
        .map((c) => c.code)
        .toList();
    return interpCodes.any((c) =>
        c == 'H' || c == 'L' || c == 'HH' || c == 'LL' || c == 'A');
  }
}

/// Reference range for an observation
class ObservationReferenceRange {
  final Quantity? low;
  final Quantity? high;
  final CodeableConcept? type;
  final String? text;

  ObservationReferenceRange({
    this.low,
    this.high,
    this.type,
    this.text,
  });

  factory ObservationReferenceRange.fromJson(Map<String, dynamic> json) {
    return ObservationReferenceRange(
      low: json['low'] != null
          ? Quantity.fromJson(json['low'] as Map<String, dynamic>)
          : null,
      high: json['high'] != null
          ? Quantity.fromJson(json['high'] as Map<String, dynamic>)
          : null,
      type: json['type'] != null
          ? CodeableConcept.fromJson(json['type'] as Map<String, dynamic>)
          : null,
      text: json['text'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (low != null) 'low': low!.toJson(),
        if (high != null) 'high': high!.toJson(),
        if (type != null) 'type': type!.toJson(),
        if (text != null) 'text': text,
      };

  String get display {
    if (text != null) return text!;
    final parts = <String>[];
    if (low != null) parts.add('>= ${low!.display}');
    if (high != null) parts.add('<= ${high!.display}');
    return parts.isEmpty ? 'No range' : parts.join(' and ');
  }
}

/// Component of an observation (for multi-value observations like blood pressure)
class ObservationComponent {
  final CodeableConcept code;
  final Quantity? valueQuantity;
  final CodeableConcept? valueCodeableConcept;
  final String? valueString;
  final List<ObservationReferenceRange> referenceRange;

  ObservationComponent({
    required this.code,
    this.valueQuantity,
    this.valueCodeableConcept,
    this.valueString,
    this.referenceRange = const [],
  });

  factory ObservationComponent.fromJson(Map<String, dynamic> json) {
    return ObservationComponent(
      code: CodeableConcept.fromJson(json['code'] as Map<String, dynamic>),
      valueQuantity: json['valueQuantity'] != null
          ? Quantity.fromJson(json['valueQuantity'] as Map<String, dynamic>)
          : null,
      valueCodeableConcept: json['valueCodeableConcept'] != null
          ? CodeableConcept.fromJson(
              json['valueCodeableConcept'] as Map<String, dynamic>)
          : null,
      valueString: json['valueString'] as String?,
      referenceRange: (json['referenceRange'] as List<dynamic>?)
              ?.map((r) =>
                  ObservationReferenceRange.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code.toJson(),
        if (valueQuantity != null) 'valueQuantity': valueQuantity!.toJson(),
        if (valueCodeableConcept != null)
          'valueCodeableConcept': valueCodeableConcept!.toJson(),
        if (valueString != null) 'valueString': valueString,
        if (referenceRange.isNotEmpty)
          'referenceRange': referenceRange.map((r) => r.toJson()).toList(),
      };

  String get valueDisplay {
    if (valueQuantity != null) return valueQuantity!.display;
    if (valueCodeableConcept != null) return valueCodeableConcept!.display;
    if (valueString != null) return valueString!;
    return 'No value';
  }
}
