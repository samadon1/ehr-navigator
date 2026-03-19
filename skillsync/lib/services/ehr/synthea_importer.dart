import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../models/fhir/fhir.dart';
import 'fhir_store.dart';

/// Result of a Synthea import operation
class ImportResult {
  final int patientsImported;
  final int conditionsImported;
  final int medicationsImported;
  final int observationsImported;
  final int encountersImported;
  final int allergiesImported;
  final List<String> errors;

  ImportResult({
    this.patientsImported = 0,
    this.conditionsImported = 0,
    this.medicationsImported = 0,
    this.observationsImported = 0,
    this.encountersImported = 0,
    this.allergiesImported = 0,
    this.errors = const [],
  });

  int get totalResources =>
      patientsImported +
      conditionsImported +
      medicationsImported +
      observationsImported +
      encountersImported +
      allergiesImported;

  @override
  String toString() =>
      'Imported: $patientsImported patients, $conditionsImported conditions, '
      '$medicationsImported medications, $observationsImported observations, '
      '$encountersImported encounters, $allergiesImported allergies';
}

/// Importer for Synthea-generated FHIR bundles
class SyntheaImporter {
  final FhirStore _store;

  SyntheaImporter(this._store);

  /// Import a Synthea FHIR bundle from a file
  Future<ImportResult> importFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return ImportResult(errors: ['File not found: $filePath']);
    }

    final content = await file.readAsString();
    return importFromString(content);
  }

  /// Import a Synthea FHIR bundle from a JSON string
  Future<ImportResult> importFromString(String jsonContent) async {
    try {
      final bundle = jsonDecode(jsonContent) as Map<String, dynamic>;
      return _importBundle(bundle);
    } catch (e) {
      return ImportResult(errors: ['Failed to parse JSON: $e']);
    }
  }

  /// Import bundled demo data from assets
  Future<ImportResult> loadDemoData() async {
    final results = ImportResult();
    var patients = 0;
    var conditions = 0;
    var medications = 0;
    var observations = 0;
    var encounters = 0;
    var allergies = 0;
    final errors = <String>[];

    try {
      // Try to load manifest
      final manifestContent =
          await rootBundle.loadString('assets/fhir/manifest.json');
      final manifest = jsonDecode(manifestContent) as List<dynamic>;

      for (final patientFile in manifest) {
        try {
          final bundleContent =
              await rootBundle.loadString('assets/fhir/$patientFile');
          final result = await importFromString(bundleContent);
          patients += result.patientsImported;
          conditions += result.conditionsImported;
          medications += result.medicationsImported;
          observations += result.observationsImported;
          encounters += result.encountersImported;
          allergies += result.allergiesImported;
          errors.addAll(result.errors);
        } catch (e) {
          errors.add('Failed to load $patientFile: $e');
        }
      }
    } catch (e) {
      // No manifest, try loading individual demo files
      debugPrint('No manifest found, trying to load demo patients directly');
      errors.add('No demo data manifest found');
    }

    return ImportResult(
      patientsImported: patients,
      conditionsImported: conditions,
      medicationsImported: medications,
      observationsImported: observations,
      encountersImported: encounters,
      allergiesImported: allergies,
      errors: errors,
    );
  }

  /// Import a FHIR bundle
  Future<ImportResult> _importBundle(Map<String, dynamic> bundle) async {
    if (bundle['resourceType'] != 'Bundle') {
      return ImportResult(errors: ['Not a FHIR Bundle']);
    }

    final entries = bundle['entry'] as List<dynamic>? ?? [];
    var patients = 0;
    var conditions = 0;
    var medications = 0;
    var observations = 0;
    var encounters = 0;
    var allergies = 0;
    final errors = <String>[];

    for (final entry in entries) {
      try {
        final resource = entry['resource'] as Map<String, dynamic>?;
        if (resource == null) continue;

        final resourceType = resource['resourceType'] as String?;
        if (resourceType == null) continue;

        switch (resourceType) {
          case 'Patient':
            await _store.saveResource(Patient.fromJson(resource));
            patients++;
            break;

          case 'Condition':
            await _store.saveResource(Condition.fromJson(resource));
            conditions++;
            break;

          case 'MedicationStatement':
            await _store.saveResource(MedicationStatement.fromJson(resource));
            medications++;
            break;

          case 'MedicationRequest':
            await _store.saveResource(MedicationRequest.fromJson(resource));
            medications++;
            break;

          case 'Observation':
            await _store.saveResource(Observation.fromJson(resource));
            observations++;
            break;

          case 'Encounter':
            await _store.saveResource(Encounter.fromJson(resource));
            encounters++;
            break;

          case 'AllergyIntolerance':
            await _store.saveResource(AllergyIntolerance.fromJson(resource));
            allergies++;
            break;

          // Skip other resource types for now
          default:
            break;
        }
      } catch (e) {
        errors.add('Failed to import resource: $e');
      }
    }

    return ImportResult(
      patientsImported: patients,
      conditionsImported: conditions,
      medicationsImported: medications,
      observationsImported: observations,
      encountersImported: encounters,
      allergiesImported: allergies,
      errors: errors,
    );
  }

  /// Create demo patients programmatically (for testing without Synthea files)
  Future<ImportResult> createDemoPatients() async {
    var patients = 0;
    var conditions = 0;
    var medications = 0;
    var allergies = 0;

    // Demo Patient 1: Diabetic patient with multiple medications
    final patient1 = Patient(
      id: 'demo-patient-1',
      name: [
        HumanName(
          given: ['John'],
          family: 'Smith',
        ),
      ],
      gender: 'male',
      birthDate: DateTime(1965, 3, 15),
      telecom: [
        ContactPoint(system: 'phone', value: '+1-555-123-4567', use: 'mobile'),
      ],
      address: [
        Address(
          line: ['123 Main Street'],
          city: 'Springfield',
          state: 'IL',
          postalCode: '62701',
        ),
      ],
    );
    await _store.saveResource(patient1);
    patients++;

    // Conditions for patient 1
    final diabetes = Condition(
      id: 'cond-diabetes-1',
      code: CodeableConcept(
        coding: [
          Coding(
            system: 'http://snomed.info/sct',
            code: '44054006',
            display: 'Type 2 Diabetes Mellitus',
          ),
        ],
        text: 'Type 2 Diabetes',
      ),
      subject: FhirReference(reference: 'Patient/demo-patient-1'),
      clinicalStatus: CodeableConcept(
        coding: [Coding(code: 'active')],
      ),
      onsetDateTime: DateTime(2015, 6, 1),
    );
    await _store.saveResource(diabetes);
    conditions++;

    final hypertension = Condition(
      id: 'cond-htn-1',
      code: CodeableConcept(
        coding: [
          Coding(
            system: 'http://snomed.info/sct',
            code: '38341003',
            display: 'Hypertension',
          ),
        ],
        text: 'Hypertension',
      ),
      subject: FhirReference(reference: 'Patient/demo-patient-1'),
      clinicalStatus: CodeableConcept(
        coding: [Coding(code: 'active')],
      ),
      onsetDateTime: DateTime(2018, 2, 15),
    );
    await _store.saveResource(hypertension);
    conditions++;

    // Medications for patient 1
    final metformin = MedicationStatement(
      id: 'med-metformin-1',
      status: 'active',
      medicationCodeableConcept: CodeableConcept(
        coding: [
          Coding(
            system: 'http://www.nlm.nih.gov/research/umls/rxnorm',
            code: '860975',
            display: 'Metformin 500 MG',
          ),
        ],
        text: 'Metformin 500mg',
      ),
      subject: FhirReference(reference: 'Patient/demo-patient-1'),
      dosage: [
        Dosage(text: 'Take 1 tablet twice daily with meals'),
      ],
    );
    await _store.saveResource(metformin);
    medications++;

    final lisinopril = MedicationStatement(
      id: 'med-lisinopril-1',
      status: 'active',
      medicationCodeableConcept: CodeableConcept(
        coding: [
          Coding(
            system: 'http://www.nlm.nih.gov/research/umls/rxnorm',
            code: '314076',
            display: 'Lisinopril 10 MG',
          ),
        ],
        text: 'Lisinopril 10mg',
      ),
      subject: FhirReference(reference: 'Patient/demo-patient-1'),
      dosage: [
        Dosage(text: 'Take 1 tablet daily'),
      ],
    );
    await _store.saveResource(lisinopril);
    medications++;

    // Warfarin + Aspirin for drug interaction demo
    final warfarin = MedicationStatement(
      id: 'med-warfarin-1',
      status: 'active',
      medicationCodeableConcept: CodeableConcept(
        coding: [
          Coding(
            system: 'http://www.nlm.nih.gov/research/umls/rxnorm',
            code: '855332',
            display: 'Warfarin 5 MG',
          ),
        ],
        text: 'Warfarin 5mg',
      ),
      subject: FhirReference(reference: 'Patient/demo-patient-1'),
      dosage: [
        Dosage(text: 'Take 1 tablet daily'),
      ],
    );
    await _store.saveResource(warfarin);
    medications++;

    final aspirin = MedicationStatement(
      id: 'med-aspirin-1',
      status: 'active',
      medicationCodeableConcept: CodeableConcept(
        coding: [
          Coding(
            system: 'http://www.nlm.nih.gov/research/umls/rxnorm',
            code: '243670',
            display: 'Aspirin 81 MG',
          ),
        ],
        text: 'Aspirin 81mg',
      ),
      subject: FhirReference(reference: 'Patient/demo-patient-1'),
      dosage: [
        Dosage(text: 'Take 1 tablet daily'),
      ],
    );
    await _store.saveResource(aspirin);
    medications++;

    // Allergy for patient 1
    final penicillinAllergy = AllergyIntolerance(
      id: 'allergy-pcn-1',
      patient: FhirReference(reference: 'Patient/demo-patient-1'),
      code: CodeableConcept(
        coding: [
          Coding(
            system: 'http://www.nlm.nih.gov/research/umls/rxnorm',
            code: '7984',
            display: 'Penicillin',
          ),
        ],
        text: 'Penicillin',
      ),
      clinicalStatus: CodeableConcept(
        coding: [Coding(code: 'active')],
      ),
      type: 'allergy',
      category: ['medication'],
      criticality: 'high',
      reaction: [
        AllergyReaction(
          manifestation: [
            CodeableConcept(text: 'Anaphylaxis'),
          ],
          severity: 'severe',
        ),
      ],
    );
    await _store.saveResource(penicillinAllergy);
    allergies++;

    // Demo Patient 2: Pediatric patient
    final patient2 = Patient(
      id: 'demo-patient-2',
      name: [
        HumanName(
          given: ['Emma'],
          family: 'Johnson',
        ),
      ],
      gender: 'female',
      birthDate: DateTime(2020, 8, 22),
      telecom: [
        ContactPoint(system: 'phone', value: '+1-555-987-6543', use: 'home'),
      ],
    );
    await _store.saveResource(patient2);
    patients++;

    // Condition for patient 2
    final asthma = Condition(
      id: 'cond-asthma-2',
      code: CodeableConcept(
        coding: [
          Coding(
            system: 'http://snomed.info/sct',
            code: '195967001',
            display: 'Asthma',
          ),
        ],
        text: 'Asthma',
      ),
      subject: FhirReference(reference: 'Patient/demo-patient-2'),
      clinicalStatus: CodeableConcept(
        coding: [Coding(code: 'active')],
      ),
      onsetDateTime: DateTime(2023, 1, 10),
    );
    await _store.saveResource(asthma);
    conditions++;

    return ImportResult(
      patientsImported: patients,
      conditionsImported: conditions,
      medicationsImported: medications,
      allergiesImported: allergies,
    );
  }
}
