/// ============================================
/// FHIR MODELS - Healthcare Data Standard
/// ============================================
///
/// FHIR = Fast Healthcare Interoperability Resources
/// Everything in healthcare is a "Resource"

// ---------------------------------------------
// Base class for all FHIR resources
// ---------------------------------------------
abstract class FhirResource {
  final String resourceType;  // "Patient", "Medication", etc.
  final String id;            // Unique identifier

  FhirResource({required this.resourceType, required this.id});

  Map<String, dynamic> toJson();
}

// ---------------------------------------------
// Patient Resource - Demographics
// ---------------------------------------------
class Patient extends FhirResource {
  final String? gender;
  final DateTime? birthDate;
  final List<HumanName> name;

  Patient({
    required super.id,
    this.gender,
    this.birthDate,
    this.name = const [],
  }) : super(resourceType: 'Patient');

  // Computed properties
  String get displayName => name.isNotEmpty ? name.first.display : 'Unknown';

  int? get age {
    if (birthDate == null) return null;
    return DateTime.now().year - birthDate!.year;
  }

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'],
      gender: json['gender'],
      birthDate: DateTime.tryParse(json['birthDate'] ?? ''),
      name: (json['name'] as List?)
          ?.map((n) => HumanName.fromJson(n))
          .toList() ?? [],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'resourceType': 'Patient',
    'id': id,
    'gender': gender,
    'birthDate': birthDate?.toIso8601String(),
    'name': name.map((n) => n.toJson()).toList(),
  };
}

// ---------------------------------------------
// Condition Resource - Diagnoses
// ---------------------------------------------
class Condition extends FhirResource {
  final String name;
  final bool isActive;
  final DateTime? onsetDate;

  Condition({
    required super.id,
    required this.name,
    this.isActive = true,
    this.onsetDate,
  }) : super(resourceType: 'Condition');

  @override
  Map<String, dynamic> toJson() => {
    'resourceType': 'Condition',
    'id': id,
    'name': name,
    'clinicalStatus': isActive ? 'active' : 'resolved',
  };
}

// ---------------------------------------------
// Medication Resource - Prescriptions
// ---------------------------------------------
class Medication extends FhirResource {
  final String name;
  final String? dosage;
  final String? frequency;
  final bool isActive;

  Medication({
    required super.id,
    required this.name,
    this.dosage,
    this.frequency,
    this.isActive = true,
  }) : super(resourceType: 'MedicationRequest');

  @override
  Map<String, dynamic> toJson() => {
    'resourceType': 'MedicationRequest',
    'id': id,
    'name': name,
    'dosage': dosage,
    'frequency': frequency,
  };
}

// ---------------------------------------------
// Observation Resource - Labs & Vitals
// ---------------------------------------------
class Observation extends FhirResource {
  final String name;      // "Blood Pressure", "HbA1c"
  final dynamic value;    // 120, 7.2, etc.
  final String? unit;     // "mmHg", "%"
  final DateTime? date;

  Observation({
    required super.id,
    required this.name,
    required this.value,
    this.unit,
    this.date,
  }) : super(resourceType: 'Observation');

  String get display => '$name: $value ${unit ?? ''}';

  @override
  Map<String, dynamic> toJson() => {
    'resourceType': 'Observation',
    'id': id,
    'name': name,
    'value': value,
    'unit': unit,
  };
}

// ---------------------------------------------
// Helper Types
// ---------------------------------------------
class HumanName {
  final List<String> given;
  final String? family;

  HumanName({this.given = const [], this.family});

  String get display => '${given.join(' ')} ${family ?? ''}'.trim();

  factory HumanName.fromJson(Map<String, dynamic> json) => HumanName(
    given: (json['given'] as List?)?.cast<String>() ?? [],
    family: json['family'],
  );

  Map<String, dynamic> toJson() => {'given': given, 'family': family};
}

class CodeableConcept {
  final String? code;
  final String? display;
  final String? system;

  CodeableConcept({this.code, this.display, this.system});
}


// ---------------------------------------------
// Example FHIR JSON (what we parse)
// ---------------------------------------------
/*
{
  "resourceType": "Patient",
  "id": "12345",
  "name": [{"given": ["John"], "family": "Smith"}],
  "gender": "male",
  "birthDate": "1980-05-15"
}

{
  "resourceType": "Condition",
  "id": "cond-1",
  "code": {"coding": [{"display": "Diabetes mellitus type 2"}]},
  "clinicalStatus": {"coding": [{"code": "active"}]}
}

{
  "resourceType": "MedicationRequest",
  "id": "med-1",
  "medicationCodeableConcept": {"text": "Metformin 500mg"},
  "dosageInstruction": [{"text": "Take twice daily"}]
}
*/
