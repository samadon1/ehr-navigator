import 'fhir_resource.dart';

/// FHIR Patient resource
class Patient extends FhirResource {
  final List<Identifier> identifier;
  final List<HumanName> name;
  final List<ContactPoint> telecom;
  final String? gender;
  final DateTime? birthDate;
  final bool? deceasedBoolean;
  final DateTime? deceasedDateTime;
  final List<Address> address;
  final CodeableConcept? maritalStatus;

  Patient({
    required super.id,
    super.meta,
    this.identifier = const [],
    this.name = const [],
    this.telecom = const [],
    this.gender,
    this.birthDate,
    this.deceasedBoolean,
    this.deceasedDateTime,
    this.address = const [],
    this.maritalStatus,
  }) : super(resourceType: 'Patient');

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] as String,
      meta: json['meta'] != null
          ? FhirMeta.fromJson(json['meta'] as Map<String, dynamic>)
          : null,
      identifier: (json['identifier'] as List<dynamic>?)
              ?.map((i) => Identifier.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      name: (json['name'] as List<dynamic>?)
              ?.map((n) => HumanName.fromJson(n as Map<String, dynamic>))
              .toList() ??
          [],
      telecom: (json['telecom'] as List<dynamic>?)
              ?.map((t) => ContactPoint.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      gender: json['gender'] as String?,
      birthDate: json['birthDate'] != null
          ? DateTime.tryParse(json['birthDate'] as String)
          : null,
      deceasedBoolean: json['deceasedBoolean'] as bool?,
      deceasedDateTime: json['deceasedDateTime'] != null
          ? DateTime.tryParse(json['deceasedDateTime'] as String)
          : null,
      address: (json['address'] as List<dynamic>?)
              ?.map((a) => Address.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      maritalStatus: json['maritalStatus'] != null
          ? CodeableConcept.fromJson(
              json['maritalStatus'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'resourceType': resourceType,
        'id': id,
        if (meta != null) 'meta': meta!.toJson(),
        if (identifier.isNotEmpty)
          'identifier': identifier.map((i) => i.toJson()).toList(),
        if (name.isNotEmpty) 'name': name.map((n) => n.toJson()).toList(),
        if (telecom.isNotEmpty)
          'telecom': telecom.map((t) => t.toJson()).toList(),
        if (gender != null) 'gender': gender,
        if (birthDate != null)
          'birthDate': birthDate!.toIso8601String().split('T').first,
        if (deceasedBoolean != null) 'deceasedBoolean': deceasedBoolean,
        if (deceasedDateTime != null)
          'deceasedDateTime': deceasedDateTime!.toIso8601String(),
        if (address.isNotEmpty)
          'address': address.map((a) => a.toJson()).toList(),
        if (maritalStatus != null) 'maritalStatus': maritalStatus!.toJson(),
      };

  @override
  String get displaySummary => displayName;

  /// Get the patient's display name
  String get displayName {
    if (name.isEmpty) return 'Unknown Patient';
    return name.first.display;
  }

  /// Get the patient's age in years
  int? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    var years = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      years--;
    }
    return years;
  }

  /// Check if patient is deceased
  bool get isDeceased =>
      deceasedBoolean == true || deceasedDateTime != null;

  /// Get formatted birth date
  String? get formattedBirthDate {
    if (birthDate == null) return null;
    return '${birthDate!.year}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}';
  }

  /// Get primary phone number
  String? get phoneNumber {
    final phone = telecom.where((t) => t.system == 'phone').firstOrNull;
    return phone?.value;
  }

  /// Get primary email
  String? get email {
    final emailContact = telecom.where((t) => t.system == 'email').firstOrNull;
    return emailContact?.value;
  }

  /// Get MRN (Medical Record Number) if available
  String? get mrn {
    final mrnId = identifier.where((i) {
      return i.type?.coding.any((c) => c.code == 'MR') == true ||
          i.system?.contains('mrn') == true ||
          i.system?.contains('medical-record') == true;
    }).firstOrNull;
    return mrnId?.value;
  }
}
