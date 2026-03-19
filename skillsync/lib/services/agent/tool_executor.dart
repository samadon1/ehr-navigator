import '../../models/agent/tool_call.dart';
import '../../models/agent/cds_alert.dart';
import '../ehr/fhir_query_service.dart';
import '../cds/cds_engine.dart';

/// Executes tool calls and returns results
class ToolExecutor {
  final FhirQueryService _fhirService;
  final CdsEngine _cdsEngine;

  ToolExecutor({
    required FhirQueryService fhirService,
    required CdsEngine cdsEngine,
  })  : _fhirService = fhirService,
        _cdsEngine = cdsEngine;

  /// Execute a single tool call
  Future<ToolResult> execute(ToolCall toolCall) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await _executeToolByName(
        toolCall.name,
        toolCall.arguments,
      );

      stopwatch.stop();

      return ToolResult(
        toolCallId: toolCall.id,
        toolName: toolCall.name,
        result: result,
        success: true,
        executionTime: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();

      return ToolResult(
        toolCallId: toolCall.id,
        toolName: toolCall.name,
        result: {'error': e.toString()},
        success: false,
        error: e.toString(),
        executionTime: stopwatch.elapsed,
      );
    }
  }

  /// Execute multiple tool calls
  Future<List<ToolResult>> executeAll(List<ToolCall> toolCalls) async {
    final results = <ToolResult>[];
    for (final toolCall in toolCalls) {
      results.add(await execute(toolCall));
    }
    return results;
  }

  /// Execute a tool by name
  Future<Map<String, dynamic>> _executeToolByName(
    String toolName,
    Map<String, dynamic> arguments,
  ) async {
    final patientId = arguments['patient_id'] as String?;
    if (patientId == null) {
      throw ArgumentError('patient_id is required');
    }

    switch (toolName) {
      case 'get_patient_info':
        return _fhirService.getPatientInfo(patientId);

      case 'get_conditions':
        return _fhirService.getConditions(
          patientId,
          status: arguments['status'] as String?,
          category: arguments['category'] as String?,
        );

      case 'get_medications':
        return _fhirService.getMedications(
          patientId,
          status: arguments['status'] as String?,
          includeHistorical: arguments['include_historical'] as bool? ?? false,
        );

      case 'get_observations':
        return _fhirService.getObservations(
          patientId,
          category: arguments['category'] as String?,
          code: arguments['code'] as String?,
          dateFrom: arguments['date_from'] != null
              ? DateTime.tryParse(arguments['date_from'] as String)
              : null,
          dateTo: arguments['date_to'] != null
              ? DateTime.tryParse(arguments['date_to'] as String)
              : null,
        );

      case 'get_encounters':
        return _fhirService.getEncounters(
          patientId,
          encounterClass: arguments['class'] as String?,
          limit: arguments['limit'] as int?,
        );

      case 'get_allergies':
        return _fhirService.getAllergies(
          patientId,
          category: arguments['category'] as String?,
        );

      case 'check_drug_interactions':
        return _checkDrugInteractions(
          patientId,
          proposedMedication: arguments['proposed_medication'] as String?,
        );

      // === TREND TOOLS ===
      case 'get_vital_trends':
        return _fhirService.getVitalTrends(
          patientId,
          vitalType: arguments['vital_type'] as String?,
          limitDays: arguments['limit_days'] as int?,
        );

      case 'get_lab_trends':
        return _fhirService.getLabTrends(
          patientId,
          labType: arguments['lab_type'] as String?,
          limitDays: arguments['limit_days'] as int?,
        );

      // === CLINICAL DECISION SUPPORT TOOLS ===
      case 'get_critical_results':
        return _fhirService.getCriticalResults(patientId);

      case 'check_overdue_screenings':
        return _fhirService.checkOverdueScreenings(patientId);

      case 'get_immunizations':
        return _fhirService.getImmunizations(patientId);

      case 'get_recent_visits':
        return _fhirService.getRecentVisits(
          patientId,
          limit: arguments['limit'] as int? ?? 5,
        );

      default:
        throw UnimplementedError('Unknown tool: $toolName');
    }
  }

  /// Check for drug interactions
  Future<Map<String, dynamic>> _checkDrugInteractions(
    String patientId, {
    String? proposedMedication,
  }) async {
    // Get current medications
    final medsResult = await _fhirService.getMedications(patientId);
    final medications =
        medsResult['medications'] as List<dynamic>? ?? [];

    // Get allergies for cross-reference
    final allergiesResult = await _fhirService.getAllergies(patientId);
    final allergies = allergiesResult['allergies'] as List<dynamic>? ?? [];

    // Run CDS checks
    final alerts = await _cdsEngine.checkDrugInteractions(
      medications: medications.cast<Map<String, dynamic>>(),
      allergies: allergies.cast<Map<String, dynamic>>(),
      proposedMedication: proposedMedication,
    );

    return {
      'patientId': patientId,
      'medicationsChecked': medications.length,
      'allergiesChecked': allergies.length,
      'proposedMedication': proposedMedication,
      'interactionsFound': alerts.length,
      'alerts': alerts.map((a) => a.toJson()).toList(),
    };
  }

  /// Get all patient data for CDS checking
  Future<Map<String, dynamic>> getPatientDataForCds(String patientId) async {
    final results = await Future.wait([
      _fhirService.getPatientInfo(patientId),
      _fhirService.getConditions(patientId),
      _fhirService.getMedications(patientId),
      _fhirService.getObservations(patientId),
      _fhirService.getAllergies(patientId),
    ]);

    return {
      'patient': results[0],
      'conditions': results[1]['conditions'] ?? [],
      'medications': results[2]['medications'] ?? [],
      'observations': results[3]['observations'] ?? [],
      'allergies': results[4]['allergies'] ?? [],
    };
  }

  /// Run all CDS checks for a patient
  Future<List<CdsAlert>> runCdsChecks(String patientId) async {
    final data = await getPatientDataForCds(patientId);
    return _cdsEngine.runAllChecks(data);
  }
}
