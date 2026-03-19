/// Base class for all FHIR resources
abstract class FhirResource {
  final String resourceType;
  final String id;
  final FhirMeta? meta;

  FhirResource({
    required this.resourceType,
    required this.id,
    this.meta,
  });

  Map<String, dynamic> toJson();

  /// Human-readable summary for display
  String get displaySummary;
}

/// FHIR Meta element
class FhirMeta {
  final String? versionId;
  final DateTime? lastUpdated;

  FhirMeta({this.versionId, this.lastUpdated});

  factory FhirMeta.fromJson(Map<String, dynamic> json) {
    return FhirMeta(
      versionId: json['versionId'] as String?,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (versionId != null) 'versionId': versionId,
        if (lastUpdated != null) 'lastUpdated': lastUpdated!.toIso8601String(),
      };
}

/// FHIR CodeableConcept - represents a coded value with optional text
class CodeableConcept {
  final List<Coding> coding;
  final String? text;

  CodeableConcept({
    this.coding = const [],
    this.text,
  });

  factory CodeableConcept.fromJson(Map<String, dynamic> json) {
    return CodeableConcept(
      coding: (json['coding'] as List<dynamic>?)
              ?.map((c) => Coding.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      text: json['text'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'coding': coding.map((c) => c.toJson()).toList(),
        if (text != null) 'text': text,
      };

  /// Get display text, preferring explicit text over coding display
  String get display => text ?? coding.firstOrNull?.display ?? 'Unknown';

  /// Get the first code value
  String? get code => coding.firstOrNull?.code;

  /// Get the system of the first coding
  String? get system => coding.firstOrNull?.system;
}

/// FHIR Coding - a single code from a code system
class Coding {
  final String? system;
  final String? code;
  final String? display;

  Coding({this.system, this.code, this.display});

  factory Coding.fromJson(Map<String, dynamic> json) {
    return Coding(
      system: json['system'] as String?,
      code: json['code'] as String?,
      display: json['display'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (system != null) 'system': system,
        if (code != null) 'code': code,
        if (display != null) 'display': display,
      };
}

/// FHIR Reference - a reference to another resource
class FhirReference {
  final String? reference;
  final String? display;

  FhirReference({this.reference, this.display});

  factory FhirReference.fromJson(Map<String, dynamic> json) {
    return FhirReference(
      reference: json['reference'] as String?,
      display: json['display'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (reference != null) 'reference': reference,
        if (display != null) 'display': display,
      };

  /// Extract the resource ID from the reference (e.g., "Patient/123" -> "123")
  String? get resourceId {
    if (reference == null) return null;
    final parts = reference!.split('/');
    return parts.length > 1 ? parts.last : reference;
  }

  /// Extract the resource type from the reference (e.g., "Patient/123" -> "Patient")
  String? get resourceTypeFromRef {
    if (reference == null) return null;
    final parts = reference!.split('/');
    return parts.length > 1 ? parts.first : null;
  }
}

/// FHIR Period - a time period with start and end
class FhirPeriod {
  final DateTime? start;
  final DateTime? end;

  FhirPeriod({this.start, this.end});

  factory FhirPeriod.fromJson(Map<String, dynamic> json) {
    return FhirPeriod(
      start: json['start'] != null
          ? DateTime.tryParse(json['start'] as String)
          : null,
      end: json['end'] != null
          ? DateTime.tryParse(json['end'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (start != null) 'start': start!.toIso8601String(),
        if (end != null) 'end': end!.toIso8601String(),
      };
}

/// FHIR Quantity - a measured amount with unit
class Quantity {
  final double? value;
  final String? unit;
  final String? system;
  final String? code;

  Quantity({this.value, this.unit, this.system, this.code});

  factory Quantity.fromJson(Map<String, dynamic> json) {
    return Quantity(
      value: (json['value'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      system: json['system'] as String?,
      code: json['code'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (value != null) 'value': value,
        if (unit != null) 'unit': unit,
        if (system != null) 'system': system,
        if (code != null) 'code': code,
      };

  String get display => '${value ?? ''} ${unit ?? ''}'.trim();
}

/// FHIR HumanName
class HumanName {
  final String? use;
  final String? family;
  final List<String> given;
  final String? text;

  HumanName({
    this.use,
    this.family,
    this.given = const [],
    this.text,
  });

  factory HumanName.fromJson(Map<String, dynamic> json) {
    return HumanName(
      use: json['use'] as String?,
      family: json['family'] as String?,
      given: (json['given'] as List<dynamic>?)
              ?.map((g) => g as String)
              .toList() ??
          [],
      text: json['text'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (use != null) 'use': use,
        if (family != null) 'family': family,
        if (given.isNotEmpty) 'given': given,
        if (text != null) 'text': text,
      };

  String get display => text ?? '${given.join(' ')} $family'.trim();
}

/// FHIR Address
class Address {
  final String? use;
  final String? type;
  final List<String> line;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;

  Address({
    this.use,
    this.type,
    this.line = const [],
    this.city,
    this.state,
    this.postalCode,
    this.country,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      use: json['use'] as String?,
      type: json['type'] as String?,
      line: (json['line'] as List<dynamic>?)
              ?.map((l) => l as String)
              .toList() ??
          [],
      city: json['city'] as String?,
      state: json['state'] as String?,
      postalCode: json['postalCode'] as String?,
      country: json['country'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (use != null) 'use': use,
        if (type != null) 'type': type,
        if (line.isNotEmpty) 'line': line,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (postalCode != null) 'postalCode': postalCode,
        if (country != null) 'country': country,
      };

  String get display =>
      [line.join(', '), city, state, postalCode, country]
          .where((s) => s != null && s.isNotEmpty)
          .join(', ');
}

/// FHIR ContactPoint (telecom)
class ContactPoint {
  final String? system; // phone, fax, email, pager, url, sms, other
  final String? value;
  final String? use; // home, work, temp, old, mobile

  ContactPoint({this.system, this.value, this.use});

  factory ContactPoint.fromJson(Map<String, dynamic> json) {
    return ContactPoint(
      system: json['system'] as String?,
      value: json['value'] as String?,
      use: json['use'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (system != null) 'system': system,
        if (value != null) 'value': value,
        if (use != null) 'use': use,
      };
}

/// FHIR Identifier
class Identifier {
  final String? system;
  final String? value;
  final String? use;
  final CodeableConcept? type;

  Identifier({this.system, this.value, this.use, this.type});

  factory Identifier.fromJson(Map<String, dynamic> json) {
    return Identifier(
      system: json['system'] as String?,
      value: json['value'] as String?,
      use: json['use'] as String?,
      type: json['type'] != null
          ? CodeableConcept.fromJson(json['type'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (system != null) 'system': system,
        if (value != null) 'value': value,
        if (use != null) 'use': use,
        if (type != null) 'type': type!.toJson(),
      };
}
