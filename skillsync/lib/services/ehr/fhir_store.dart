import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/fhir/fhir.dart';

/// Local JSON file-based FHIR data store
class FhirStore {
  late Directory _dataDir;
  bool _initialized = false;

  /// Initialize the store
  Future<void> initialize() async {
    if (_initialized) return;

    final appDir = await getApplicationDocumentsDirectory();
    _dataDir = Directory('${appDir.path}/fhir_data');
    await _dataDir.create(recursive: true);
    _initialized = true;
    debugPrint('FhirStore initialized at: ${_dataDir.path}');
  }

  /// Ensure store is initialized
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('FhirStore not initialized. Call initialize() first.');
    }
  }

  /// Get directory for a resource type
  Directory _getResourceDir(String resourceType) {
    return Directory('${_dataDir.path}/$resourceType');
  }

  /// Save a FHIR resource
  Future<void> saveResource(FhirResource resource) async {
    _ensureInitialized();
    final dir = _getResourceDir(resource.resourceType);
    await dir.create(recursive: true);
    final file = File('${dir.path}/${resource.id}.json');
    await file.writeAsString(jsonEncode(resource.toJson()));
  }

  /// Save multiple resources
  Future<void> saveResources(List<FhirResource> resources) async {
    for (final resource in resources) {
      await saveResource(resource);
    }
  }

  /// Get a specific resource by type and ID
  Future<Map<String, dynamic>?> getResource(
    String resourceType,
    String id,
  ) async {
    _ensureInitialized();
    final file = File('${_getResourceDir(resourceType).path}/$id.json');
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  /// Get a Patient by ID
  Future<Patient?> getPatient(String id) async {
    final json = await getResource('Patient', id);
    if (json == null) return null;
    return Patient.fromJson(json);
  }

  /// Get all patients
  Future<List<Patient>> getAllPatients() async {
    _ensureInitialized();
    final dir = _getResourceDir('Patient');
    if (!await dir.exists()) return [];

    final patients = <Patient>[];
    await for (final file in dir.list()) {
      if (file is File && file.path.endsWith('.json')) {
        try {
          final content = await file.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          patients.add(Patient.fromJson(json));
        } catch (e) {
          debugPrint('Error loading patient from ${file.path}: $e');
        }
      }
    }
    return patients;
  }

  /// Get conditions for a patient
  Future<List<Condition>> getConditions(
    String patientId, {
    String? status,
  }) async {
    return _getResourcesForPatient<Condition>(
      'Condition',
      patientId,
      (json) => Condition.fromJson(json),
      filter: (condition) {
        if (status == null) return true;
        if (status == 'active') return condition.isActive;
        if (status == 'resolved') return condition.isResolved;
        return true;
      },
    );
  }

  /// Get medications for a patient (both MedicationStatement and MedicationRequest)
  Future<List<MedicationStatement>> getMedications(
    String patientId, {
    String? status,
    bool includeHistorical = false,
  }) async {
    final medications = await _getResourcesForPatient<MedicationStatement>(
      'MedicationStatement',
      patientId,
      (json) => MedicationStatement.fromJson(json),
      filter: (med) {
        if (status == null && includeHistorical) return true;
        if (status == 'active') return med.isActive;
        if (!includeHistorical) return med.isActive;
        return true;
      },
    );

    // Also try MedicationRequest if no MedicationStatement found
    if (medications.isEmpty) {
      final requests = await _getResourcesForPatient<MedicationRequest>(
        'MedicationRequest',
        patientId,
        (json) => MedicationRequest.fromJson(json),
        filter: (req) {
          if (status == 'active') return req.isActive;
          return true;
        },
      );

      // Convert MedicationRequest to MedicationStatement for uniform handling
      return requests
          .map((req) => MedicationStatement(
                id: req.id,
                status: req.status,
                medicationCodeableConcept: req.medicationCodeableConcept,
                medicationReference: req.medicationReference,
                subject: req.subject,
                dosage: req.dosageInstruction,
                reasonCode: req.reasonCode,
              ))
          .toList();
    }

    return medications;
  }

  /// Get observations for a patient
  Future<List<Observation>> getObservations(
    String patientId, {
    String? category,
    String? code,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    return _getResourcesForPatient<Observation>(
      'Observation',
      patientId,
      (json) => Observation.fromJson(json),
      filter: (obs) {
        if (category != null && obs.primaryCategory != category) return false;
        if (code != null && obs.loincCode != code) return false;
        if (dateFrom != null && obs.effectiveDate != null) {
          if (obs.effectiveDate!.isBefore(dateFrom)) return false;
        }
        if (dateTo != null && obs.effectiveDate != null) {
          if (obs.effectiveDate!.isAfter(dateTo)) return false;
        }
        return true;
      },
    );
  }

  /// Get encounters for a patient
  Future<List<Encounter>> getEncounters(
    String patientId, {
    String? encounterClass,
    int? limit,
  }) async {
    var encounters = await _getResourcesForPatient<Encounter>(
      'Encounter',
      patientId,
      (json) => Encounter.fromJson(json),
      filter: (enc) {
        if (encounterClass != null &&
            encounterClass != 'all' &&
            enc.encounterClass?.code != encounterClass) {
          return false;
        }
        return true;
      },
    );

    // Sort by date descending
    encounters.sort((a, b) {
      final aDate = a.period?.start ?? DateTime(1900);
      final bDate = b.period?.start ?? DateTime(1900);
      return bDate.compareTo(aDate);
    });

    if (limit != null && encounters.length > limit) {
      encounters = encounters.take(limit).toList();
    }

    return encounters;
  }

  /// Get allergies for a patient
  Future<List<AllergyIntolerance>> getAllergies(
    String patientId, {
    String? category,
  }) async {
    return _getResourcesForPatient<AllergyIntolerance>(
      'AllergyIntolerance',
      patientId,
      (json) => AllergyIntolerance.fromJson(json),
      filter: (allergy) {
        if (!allergy.isActive) return false;
        if (category != null &&
            category != 'all' &&
            !allergy.category.contains(category)) {
          return false;
        }
        return true;
      },
    );
  }

  /// Get immunizations for a patient
  Future<List<Immunization>> getImmunizations(String patientId) async {
    return _getResourcesForPatient<Immunization>(
      'Immunization',
      patientId,
      (json) => Immunization.fromJson(json),
      filter: (imm) => imm.isCompleted,
    );
  }

  /// Get a manifest of available resources for a patient
  Future<Map<String, List<String>>> getPatientManifest(String patientId) async {
    _ensureInitialized();
    final manifest = <String, List<String>>{};

    final resourceTypes = [
      'Condition',
      'MedicationStatement',
      'MedicationRequest',
      'Observation',
      'Encounter',
      'AllergyIntolerance',
      'Immunization',
    ];

    for (final resourceType in resourceTypes) {
      final dir = _getResourceDir(resourceType);
      if (!await dir.exists()) continue;

      final codes = <String>[];
      await for (final file in dir.list()) {
        if (file is File && file.path.endsWith('.json')) {
          try {
            final content = await file.readAsString();
            final json = jsonDecode(content) as Map<String, dynamic>;

            // Check if this resource belongs to the patient
            final subject = json['subject'] ?? json['patient'];
            if (subject != null) {
              final ref = subject['reference'] as String?;
              if (ref != null && ref.contains(patientId)) {
                // Extract code for manifest
                final code = json['code'] as Map<String, dynamic>?;
                if (code != null) {
                  final coding = code['coding'] as List<dynamic>?;
                  if (coding != null && coding.isNotEmpty) {
                    final firstCode =
                        (coding.first as Map<String, dynamic>)['code'] as String?;
                    if (firstCode != null) codes.add(firstCode);
                  }
                }
              }
            }
          } catch (e) {
            // Skip invalid files
          }
        }
      }

      if (codes.isNotEmpty) {
        manifest[resourceType] = codes.toSet().toList();
      }
    }

    return manifest;
  }

  /// Helper to get resources for a specific patient
  Future<List<T>> _getResourcesForPatient<T>(
    String resourceType,
    String patientId,
    T Function(Map<String, dynamic>) fromJson, {
    bool Function(T)? filter,
  }) async {
    _ensureInitialized();
    final dir = _getResourceDir(resourceType);
    if (!await dir.exists()) return [];

    final resources = <T>[];
    await for (final file in dir.list()) {
      if (file is File && file.path.endsWith('.json')) {
        try {
          final content = await file.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;

          // Check if this resource belongs to the patient
          final subject = json['subject'] ?? json['patient'];
          if (subject != null) {
            final ref = subject['reference'] as String?;
            if (ref != null && ref.contains(patientId)) {
              final resource = fromJson(json);
              if (filter == null || filter(resource)) {
                resources.add(resource);
              }
            }
          }
        } catch (e) {
          debugPrint('Error loading $resourceType: $e');
        }
      }
    }

    return resources;
  }

  /// Delete all data
  Future<void> clearAll() async {
    _ensureInitialized();
    if (await _dataDir.exists()) {
      await _dataDir.delete(recursive: true);
      await _dataDir.create(recursive: true);
    }
  }

  /// Delete a specific resource
  Future<void> deleteResource(String resourceType, String id) async {
    _ensureInitialized();
    final file = File('${_getResourceDir(resourceType).path}/$id.json');
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Check if store has any data
  Future<bool> hasData() async {
    _ensureInitialized();
    final patients = await getAllPatients();
    return patients.isNotEmpty;
  }

  /// Get data directory path (for debugging)
  String get dataPath => _dataDir.path;
}
