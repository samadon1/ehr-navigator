import '../../models/fhir/fhir.dart';
import 'fhir_store.dart';

/// High-level service for querying FHIR data
/// This service wraps FhirStore and provides methods that match the agent tools
class FhirQueryService {
  final FhirStore _store;

  FhirQueryService({FhirStore? store}) : _store = store ?? FhirStore();

  /// Initialize the service
  Future<void> initialize() async {
    await _store.initialize();
  }

  /// Get the underlying store
  FhirStore get store => _store;

  /// Get patient info
  Future<Map<String, dynamic>> getPatientInfo(String patientId) async {
    final patient = await _store.getPatient(patientId);
    if (patient == null) {
      return {'error': 'Patient not found'};
    }

    return {
      'id': patient.id,
      'name': patient.displayName,
      'gender': patient.gender,
      'birthDate': patient.formattedBirthDate,
      'age': patient.age,
      'phone': patient.phoneNumber,
      'email': patient.email,
      'mrn': patient.mrn,
      'address': patient.address.isNotEmpty ? patient.address.first.display : null,
      'isDeceased': patient.isDeceased,
    };
  }

  /// Get all patients
  Future<List<Patient>> getAllPatients() async {
    return _store.getAllPatients();
  }

  /// Get conditions for a patient
  Future<Map<String, dynamic>> getConditions(
    String patientId, {
    String? status,
    String? category,
  }) async {
    final conditions = await _store.getConditions(patientId, status: status);

    if (conditions.isEmpty) {
      return {
        'patientId': patientId,
        'conditions': [],
        'message': 'No conditions found',
      };
    }

    return {
      'patientId': patientId,
      'count': conditions.length,
      'conditions': conditions
          .map((c) => {
                'id': c.id,
                'name': c.displaySummary,
                'code': c.code.code,
                'status': c.clinicalStatus?.coding.firstOrNull?.code,
                'onsetDate': c.onsetDateTime?.toIso8601String(),
                'isActive': c.isActive,
              })
          .toList(),
    };
  }

  /// Get medications for a patient
  Future<Map<String, dynamic>> getMedications(
    String patientId, {
    String? status,
    bool includeHistorical = false,
  }) async {
    final medications = await _store.getMedications(
      patientId,
      status: status,
      includeHistorical: includeHistorical,
    );

    if (medications.isEmpty) {
      return {
        'patientId': patientId,
        'medications': [],
        'message': 'No medications found',
      };
    }

    return {
      'patientId': patientId,
      'count': medications.length,
      'medications': medications
          .map((m) => {
                'id': m.id,
                'name': m.medicationName,
                'rxNormCode': m.rxNormCode,
                'status': m.status,
                'dosage': m.dosageInstructions,
                'isActive': m.isActive,
              })
          .toList(),
    };
  }

  /// Get observations for a patient
  Future<Map<String, dynamic>> getObservations(
    String patientId, {
    String? category,
    String? code,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final observations = await _store.getObservations(
      patientId,
      category: category,
      code: code,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );

    // Sort by date descending
    observations.sort((a, b) {
      final aDate = a.effectiveDate ?? DateTime(1900);
      final bDate = b.effectiveDate ?? DateTime(1900);
      return bDate.compareTo(aDate);
    });

    if (observations.isEmpty) {
      return {
        'patientId': patientId,
        'observations': [],
        'message': 'No observations found',
      };
    }

    return {
      'patientId': patientId,
      'count': observations.length,
      'observations': observations
          .map((o) => {
                'id': o.id,
                'name': o.code.display,
                'loincCode': o.loincCode,
                'value': o.valueDisplay,
                'unit': o.valueQuantity?.unit,
                'date': o.effectiveDate?.toIso8601String(),
                'category': o.primaryCategory,
                'isAbnormal': o.isAbnormal,
              })
          .toList(),
    };
  }

  /// Get encounters for a patient
  Future<Map<String, dynamic>> getEncounters(
    String patientId, {
    String? encounterClass,
    int? limit,
  }) async {
    final encounters = await _store.getEncounters(
      patientId,
      encounterClass: encounterClass,
      limit: limit,
    );

    if (encounters.isEmpty) {
      return {
        'patientId': patientId,
        'encounters': [],
        'message': 'No encounters found',
      };
    }

    return {
      'patientId': patientId,
      'count': encounters.length,
      'encounters': encounters
          .map((e) => {
                'id': e.id,
                'summary': e.displaySummary,
                'class': e.classDisplay,
                'status': e.status,
                'startDate': e.period?.start?.toIso8601String(),
                'endDate': e.period?.end?.toIso8601String(),
                'reason': e.primaryReason,
              })
          .toList(),
    };
  }

  /// Get allergies for a patient
  Future<Map<String, dynamic>> getAllergies(
    String patientId, {
    String? category,
  }) async {
    final allergies = await _store.getAllergies(patientId, category: category);

    if (allergies.isEmpty) {
      return {
        'patientId': patientId,
        'allergies': [],
        'message': 'No allergies found',
      };
    }

    return {
      'patientId': patientId,
      'count': allergies.length,
      'allergies': allergies
          .map((a) => {
                'id': a.id,
                'allergen': a.allergenName,
                'rxNormCode': a.rxNormCode,
                'snomedCode': a.snomedCode,
                'type': a.type,
                'category': a.category,
                'criticality': a.criticality,
                'isHighCriticality': a.isHighCriticality,
                'manifestations': a.manifestations,
              })
          .toList(),
    };
  }

  /// Get patient manifest (available resource types and codes)
  Future<Map<String, dynamic>> getPatientManifest(String patientId) async {
    final manifest = await _store.getPatientManifest(patientId);
    final patient = await _store.getPatient(patientId);

    return {
      'patientId': patientId,
      'patientName': patient?.displayName ?? 'Unknown',
      'availableResources': manifest.map((type, codes) => MapEntry(
            type,
            {
              'count': codes.length,
              'codes': codes.take(10).toList(), // Limit codes for brevity
            },
          )),
    };
  }

  /// Get vital sign trends over time
  /// Returns time-series data for a specific vital type or all vitals
  Future<Map<String, dynamic>> getVitalTrends(
    String patientId, {
    String? vitalType, // 'blood_pressure', 'heart_rate', 'weight', 'temperature', 'bmi', 'respiratory_rate', 'oxygen_saturation'
    int? limitDays, // Limit to last N days
  }) async {
    // Common vital sign LOINC codes
    final vitalCodes = <String, List<String>>{
      'blood_pressure': ['85354-9', '8480-6', '8462-4'], // Panel, Systolic, Diastolic
      'heart_rate': ['8867-4'],
      'weight': ['29463-7'],
      'height': ['8302-2'],
      'temperature': ['8310-5'],
      'bmi': ['39156-5'],
      'respiratory_rate': ['9279-1'],
      'oxygen_saturation': ['59408-5', '2708-6'],
    };

    DateTime? dateFrom;
    if (limitDays != null) {
      dateFrom = DateTime.now().subtract(Duration(days: limitDays));
    }

    final observations = await _store.getObservations(
      patientId,
      category: 'vital-signs',
      dateFrom: dateFrom,
    );

    // Filter by vital type if specified
    List<Observation> filtered = observations;
    if (vitalType != null && vitalCodes.containsKey(vitalType)) {
      final codes = vitalCodes[vitalType]!;
      filtered = observations.where((o) {
        final loincCode = o.loincCode;
        return loincCode != null && codes.contains(loincCode);
      }).toList();
    }

    // Sort by date ascending for trend analysis
    filtered.sort((a, b) {
      final aDate = a.effectiveDate ?? DateTime(1900);
      final bDate = b.effectiveDate ?? DateTime(1900);
      return aDate.compareTo(bDate);
    });

    // Group by vital type and build time series
    final trendData = <String, List<Map<String, dynamic>>>{};

    for (final obs in filtered) {
      final name = obs.code.display ?? 'Unknown';
      final key = obs.loincCode ?? name;

      trendData[key] ??= [];

      // Handle blood pressure with components
      if (obs.component.isNotEmpty) {
        for (final comp in obs.component) {
          final compName = comp.code.display ?? 'Component';
          final compKey = comp.code.coding.firstOrNull?.code ?? compName;
          trendData[compKey] ??= [];
          if (comp.valueQuantity != null) {
            trendData[compKey]!.add({
              'date': obs.effectiveDate?.toIso8601String(),
              'value': comp.valueQuantity!.value,
              'unit': comp.valueQuantity!.unit,
              'display': compName,
            });
          }
        }
      } else if (obs.valueQuantity != null) {
        trendData[key]!.add({
          'date': obs.effectiveDate?.toIso8601String(),
          'value': obs.valueQuantity!.value,
          'unit': obs.valueQuantity!.unit,
          'display': name,
        });
      }
    }

    // Calculate statistics for each vital
    final statistics = <String, Map<String, dynamic>>{};
    for (final entry in trendData.entries) {
      if (entry.value.isEmpty) continue;
      final values = entry.value
          .map((e) => e['value'] as num?)
          .whereType<num>()
          .toList();
      if (values.isEmpty) continue;

      final latest = entry.value.last;
      final oldest = entry.value.first;
      statistics[entry.key] = {
        'display': latest['display'],
        'unit': latest['unit'],
        'count': values.length,
        'latest': latest['value'],
        'latestDate': latest['date'],
        'oldest': oldest['value'],
        'oldestDate': oldest['date'],
        'min': values.reduce((a, b) => a < b ? a : b),
        'max': values.reduce((a, b) => a > b ? a : b),
        'average': values.reduce((a, b) => a + b) / values.length,
        'trend': values.length > 1
            ? (values.last > values.first ? 'increasing' : values.last < values.first ? 'decreasing' : 'stable')
            : 'insufficient_data',
      };
    }

    return {
      'patientId': patientId,
      'vitalType': vitalType,
      'limitDays': limitDays,
      'dataPoints': filtered.length,
      'trends': trendData,
      'statistics': statistics,
    };
  }

  /// Get lab result trends over time
  Future<Map<String, dynamic>> getLabTrends(
    String patientId, {
    String? labType, // LOINC code or common name like 'glucose', 'hba1c', 'cholesterol', 'creatinine'
    int? limitDays,
  }) async {
    // Common lab LOINC codes
    final labCodes = <String, List<String>>{
      'glucose': ['2345-7', '2339-0', '41653-7'], // Glucose, Glucose fasting, Glucose random
      'hba1c': ['4548-4', '17856-6'], // HbA1c
      'cholesterol': ['2093-3'], // Total cholesterol
      'ldl': ['2089-1', '13457-7'], // LDL
      'hdl': ['2085-9'], // HDL
      'triglycerides': ['2571-8'],
      'creatinine': ['2160-0', '38483-4'],
      'egfr': ['33914-3', '48642-3', '62238-1'],
      'potassium': ['2823-3'],
      'sodium': ['2951-2'],
      'hemoglobin': ['718-7'],
      'wbc': ['6690-2'],
      'platelets': ['777-3'],
    };

    DateTime? dateFrom;
    if (limitDays != null) {
      dateFrom = DateTime.now().subtract(Duration(days: limitDays));
    }

    final observations = await _store.getObservations(
      patientId,
      category: 'laboratory',
      dateFrom: dateFrom,
    );

    // Filter by lab type if specified
    List<Observation> filtered = observations;
    if (labType != null) {
      final codes = labCodes[labType.toLowerCase()];
      if (codes != null) {
        filtered = observations.where((o) {
          final loincCode = o.loincCode;
          return loincCode != null && codes.contains(loincCode);
        }).toList();
      } else {
        // Try direct LOINC code match
        filtered = observations.where((o) => o.loincCode == labType).toList();
      }
    }

    // Sort by date ascending
    filtered.sort((a, b) {
      final aDate = a.effectiveDate ?? DateTime(1900);
      final bDate = b.effectiveDate ?? DateTime(1900);
      return aDate.compareTo(bDate);
    });

    // Build time series grouped by lab type
    final trendData = <String, List<Map<String, dynamic>>>{};

    for (final obs in filtered) {
      final name = obs.code.display ?? 'Unknown';
      final key = obs.loincCode ?? name;

      trendData[key] ??= [];

      if (obs.valueQuantity != null) {
        trendData[key]!.add({
          'date': obs.effectiveDate?.toIso8601String(),
          'value': obs.valueQuantity!.value,
          'unit': obs.valueQuantity!.unit,
          'display': name,
          'isAbnormal': obs.isAbnormal,
          'referenceRange': obs.referenceRange.isNotEmpty
              ? obs.referenceRange.first.display
              : null,
        });
      }
    }

    // Calculate statistics
    final statistics = <String, Map<String, dynamic>>{};
    for (final entry in trendData.entries) {
      if (entry.value.isEmpty) continue;
      final values = entry.value
          .map((e) => e['value'] as num?)
          .whereType<num>()
          .toList();
      if (values.isEmpty) continue;

      final latest = entry.value.last;
      final abnormalCount = entry.value.where((e) => e['isAbnormal'] == true).length;

      statistics[entry.key] = {
        'display': latest['display'],
        'unit': latest['unit'],
        'count': values.length,
        'latest': latest['value'],
        'latestDate': latest['date'],
        'latestAbnormal': latest['isAbnormal'],
        'referenceRange': latest['referenceRange'],
        'min': values.reduce((a, b) => a < b ? a : b),
        'max': values.reduce((a, b) => a > b ? a : b),
        'average': values.reduce((a, b) => a + b) / values.length,
        'abnormalCount': abnormalCount,
        'trend': values.length > 1
            ? (values.last > values.first ? 'increasing' : values.last < values.first ? 'decreasing' : 'stable')
            : 'insufficient_data',
      };
    }

    return {
      'patientId': patientId,
      'labType': labType,
      'limitDays': limitDays,
      'dataPoints': filtered.length,
      'trends': trendData,
      'statistics': statistics,
    };
  }

  /// Get critical/abnormal lab results that need attention
  Future<Map<String, dynamic>> getCriticalResults(String patientId) async {
    final observations = await _store.getObservations(
      patientId,
      category: 'laboratory',
    );

    // Filter to abnormal results
    final abnormal = observations.where((o) => o.isAbnormal).toList();

    // Sort by date descending (most recent first)
    abnormal.sort((a, b) {
      final aDate = a.effectiveDate ?? DateTime(1900);
      final bDate = b.effectiveDate ?? DateTime(1900);
      return bDate.compareTo(aDate);
    });

    // Group by recency
    final now = DateTime.now();
    final last7Days = abnormal.where((o) {
      final date = o.effectiveDate;
      return date != null && now.difference(date).inDays <= 7;
    }).toList();
    final last30Days = abnormal.where((o) {
      final date = o.effectiveDate;
      return date != null && now.difference(date).inDays <= 30 && now.difference(date).inDays > 7;
    }).toList();
    final older = abnormal.where((o) {
      final date = o.effectiveDate;
      return date == null || now.difference(date).inDays > 30;
    }).toList();

    Map<String, dynamic> formatObs(Observation o) => {
      'id': o.id,
      'name': o.code.display,
      'loincCode': o.loincCode,
      'value': o.valueDisplay,
      'unit': o.valueQuantity?.unit,
      'date': o.effectiveDate?.toIso8601String(),
      'referenceRange': o.referenceRange.isNotEmpty ? o.referenceRange.first.display : null,
      'interpretation': o.interpretation.isNotEmpty ? o.interpretation.first.display : null,
    };

    return {
      'patientId': patientId,
      'totalAbnormal': abnormal.length,
      'urgent': {
        'label': 'Last 7 days',
        'count': last7Days.length,
        'results': last7Days.map(formatObs).toList(),
      },
      'recent': {
        'label': 'Last 30 days',
        'count': last30Days.length,
        'results': last30Days.map(formatObs).toList(),
      },
      'older': {
        'label': 'Older than 30 days',
        'count': older.length,
        'results': older.take(10).map(formatObs).toList(),
      },
    };
  }

  /// Get immunization records
  Future<Map<String, dynamic>> getImmunizations(String patientId) async {
    final immunizations = await _store.getImmunizations(patientId);

    // Sort by date descending
    immunizations.sort((a, b) {
      final aDate = a.occurrenceDateTime ?? DateTime(1900);
      final bDate = b.occurrenceDateTime ?? DateTime(1900);
      return bDate.compareTo(aDate);
    });

    // Group by vaccine type
    final byType = <String, List<Immunization>>{};
    for (final imm in immunizations) {
      final name = imm.vaccineCode.display ?? 'Unknown';
      byType[name] ??= [];
      byType[name]!.add(imm);
    }

    return {
      'patientId': patientId,
      'count': immunizations.length,
      'immunizations': immunizations.map((i) {
        return {
          'id': i.id,
          'vaccine': i.vaccineCode.display,
          'cvxCode': i.cvxCode,
          'date': i.occurrenceDateTime?.toIso8601String(),
          'status': i.status,
          'site': i.site?.display,
          'route': i.route?.display,
        };
      }).toList(),
      'byVaccineType': byType.map((name, list) => MapEntry(name, {
        'count': list.length,
        'lastDate': list.first.occurrenceDateTime?.toIso8601String(),
        'dates': list.map((i) => i.occurrenceDateTime?.toIso8601String()).toList(),
      })),
    };
  }

  /// Get recent visits/encounters for handoff context
  Future<Map<String, dynamic>> getRecentVisits(
    String patientId, {
    int limit = 5,
  }) async {
    final encounters = await _store.getEncounters(patientId, limit: limit);

    // For each encounter, get associated observations and conditions
    final visitsWithContext = <Map<String, dynamic>>[];

    for (final enc in encounters) {
      // Get observations from this encounter period
      final observations = await _store.getObservations(
        patientId,
        dateFrom: enc.period?.start,
        dateTo: enc.period?.end ?? enc.period?.start?.add(const Duration(days: 1)),
      );

      visitsWithContext.add({
        'id': enc.id,
        'type': enc.classDisplay,
        'status': enc.status,
        'startDate': enc.period?.start?.toIso8601String(),
        'endDate': enc.period?.end?.toIso8601String(),
        'reason': enc.primaryReason,
        'summary': enc.displaySummary,
        'vitalsCount': observations.where((o) => o.isVitalSign).length,
        'labsCount': observations.where((o) => o.isLaboratory).length,
        'keyFindings': observations.take(5).map((o) => '${o.code.display}: ${o.valueDisplay}').toList(),
      });
    }

    return {
      'patientId': patientId,
      'visitCount': encounters.length,
      'visits': visitsWithContext,
    };
  }

  /// Check for overdue screenings and care gaps
  Future<Map<String, dynamic>> checkOverdueScreenings(String patientId) async {
    final patient = await _store.getPatient(patientId);
    if (patient == null) {
      return {'error': 'Patient not found'};
    }

    final observations = await _store.getObservations(patientId);
    final conditions = await _store.getConditions(patientId);

    final age = patient.age ?? 0;
    final gender = patient.gender?.toLowerCase() ?? '';
    final now = DateTime.now();

    final careGaps = <Map<String, dynamic>>[];

    // Helper to check last screening date
    DateTime? lastScreeningDate(List<String> loincCodes) {
      final matching = observations.where((o) {
        final code = o.loincCode;
        return code != null && loincCodes.contains(code);
      }).toList();
      if (matching.isEmpty) return null;
      matching.sort((a, b) {
        final aDate = a.effectiveDate ?? DateTime(1900);
        final bDate = b.effectiveDate ?? DateTime(1900);
        return bDate.compareTo(aDate);
      });
      return matching.first.effectiveDate;
    }

    // Blood pressure - annual for adults
    if (age >= 18) {
      final lastBP = lastScreeningDate(['85354-9', '8480-6']);
      if (lastBP == null || now.difference(lastBP).inDays > 365) {
        careGaps.add({
          'screening': 'Blood Pressure',
          'recommendation': 'Annual blood pressure check for adults',
          'lastDate': lastBP?.toIso8601String(),
          'dueStatus': lastBP == null ? 'never_done' : 'overdue',
          'priority': 'medium',
        });
      }
    }

    // Lipid panel - every 5 years for adults 20-79, or annually if diabetic/CVD risk
    if (age >= 20 && age < 80) {
      final lastLipid = lastScreeningDate(['2093-3', '57698-3']); // cholesterol panel
      final hasDiabetes = conditions.any((c) =>
          c.code.code?.contains('44054006') == true || // diabetes
          c.displaySummary.toLowerCase().contains('diabetes'));
      final intervalDays = hasDiabetes ? 365 : 365 * 5;

      if (lastLipid == null || now.difference(lastLipid).inDays > intervalDays) {
        careGaps.add({
          'screening': 'Lipid Panel',
          'recommendation': hasDiabetes
              ? 'Annual lipid panel (patient has diabetes)'
              : 'Lipid panel every 5 years for cardiovascular risk',
          'lastDate': lastLipid?.toIso8601String(),
          'dueStatus': lastLipid == null ? 'never_done' : 'overdue',
          'priority': hasDiabetes ? 'high' : 'medium',
        });
      }
    }

    // HbA1c - for diabetic patients, every 3-6 months
    final hasDiabetes = conditions.any((c) =>
        c.code.code?.contains('44054006') == true ||
        c.displaySummary.toLowerCase().contains('diabetes'));
    if (hasDiabetes) {
      final lastHbA1c = lastScreeningDate(['4548-4', '17856-6']);
      if (lastHbA1c == null || now.difference(lastHbA1c).inDays > 180) {
        careGaps.add({
          'screening': 'HbA1c',
          'recommendation': 'HbA1c every 3-6 months for diabetes management',
          'lastDate': lastHbA1c?.toIso8601String(),
          'dueStatus': lastHbA1c == null ? 'never_done' : 'overdue',
          'priority': 'high',
        });
      }
    }

    // eGFR/Creatinine - annual for diabetic/hypertensive patients
    final hasHypertension = conditions.any((c) =>
        c.displaySummary.toLowerCase().contains('hypertension'));
    if (hasDiabetes || hasHypertension) {
      final lastEgfr = lastScreeningDate(['33914-3', '48642-3', '62238-1', '2160-0']);
      if (lastEgfr == null || now.difference(lastEgfr).inDays > 365) {
        careGaps.add({
          'screening': 'Kidney Function (eGFR/Creatinine)',
          'recommendation': 'Annual kidney function test for chronic disease monitoring',
          'lastDate': lastEgfr?.toIso8601String(),
          'dueStatus': lastEgfr == null ? 'never_done' : 'overdue',
          'priority': 'high',
        });
      }
    }

    // Colorectal cancer screening - ages 45-75
    if (age >= 45 && age <= 75) {
      final lastColon = lastScreeningDate(['77353-1', '57803-9']); // colonoscopy, FIT
      if (lastColon == null || now.difference(lastColon).inDays > 365 * 10) {
        careGaps.add({
          'screening': 'Colorectal Cancer Screening',
          'recommendation': 'Colonoscopy every 10 years or annual FIT for ages 45-75',
          'lastDate': lastColon?.toIso8601String(),
          'dueStatus': lastColon == null ? 'never_done' : 'overdue',
          'priority': 'medium',
        });
      }
    }

    return {
      'patientId': patientId,
      'patientAge': age,
      'patientGender': gender,
      'conditionsConsidered': {
        'diabetes': hasDiabetes,
        'hypertension': hasHypertension,
      },
      'careGapsCount': careGaps.length,
      'careGaps': careGaps,
    };
  }

  /// Check if data exists
  Future<bool> hasData() async {
    return _store.hasData();
  }

  /// Clear all data
  Future<void> clearAll() async {
    await _store.clearAll();
  }
}
