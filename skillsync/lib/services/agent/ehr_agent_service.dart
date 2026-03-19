import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cactus/cactus.dart' as cactus;
import '../../models/agent/agent_state.dart';
import '../../models/agent/tool_call.dart';
import '../../models/agent/cds_alert.dart';
import '../ehr/fhir_query_service.dart';
import '../cds/cds_engine.dart';
import 'tool_registry.dart';
import 'tool_executor.dart';

/// Result of parsing model output - separates thinking from response
class ParsedModelOutput {
  final String response;
  final String? thinking;

  ParsedModelOutput({required this.response, this.thinking});
}

/// Parse model output to extract thinking content separately
ParsedModelOutput _parseModelOutput(String rawResponse) {
  String? thinking;
  var response = rawResponse;

  // Extract thinking content (Qwen3 thinking mode)
  final thinkRegex = RegExp(r'<think>(.*?)</think>', dotAll: true);
  final match = thinkRegex.firstMatch(response);
  if (match != null) {
    thinking = match.group(1)?.trim();
    response = response.replaceAll(thinkRegex, '');
  }

  // Clean the response
  response = _cleanModelResponse(response);

  return ParsedModelOutput(
    response: response,
    thinking: thinking?.isNotEmpty == true ? thinking : null,
  );
}

/// Clean model output by removing special tokens and artifacts
String _cleanModelResponse(String response) {
  var cleaned = response
      // Remove Gemma-family tokens
      .replaceAll('<end_of_turn>', '')
      .replaceAll('<start_of_turn>', '')
      .replaceAll('<eos>', '')
      .replaceAll('<bos>', '')
      // Remove Qwen tokens
      .replaceAll('<|im_end|>', '')
      .replaceAll('<|im_start|>', '')
      .replaceAll('<|endoftext|>', '')
      // Remove other common tokens
      .replaceAll('[/INST]', '')
      .replaceAll('[INST]', '')
      .replaceAll('</s>', '')
      .replaceAll('<s>', '')
      // Clean up whitespace
      .trim();

  // Remove markdown code fences that wrap the entire response
  if (cleaned.startsWith('```') && cleaned.endsWith('```')) {
    cleaned = cleaned.substring(3);
    if (cleaned.startsWith('json\n')) cleaned = cleaned.substring(5);
    if (cleaned.endsWith('```')) cleaned = cleaned.substring(0, cleaned.length - 3);
    cleaned = cleaned.trim();
  }

  return cleaned;
}

/// Main EHR Navigator Agent Service
/// Orchestrates the agent workflow: Discovery -> Routing -> Execute -> Filter -> CDS -> Synthesize
/// Uses CactusLM from pub.dev for on-device inference
class EhrAgentService {
  final FhirQueryService _fhirService;
  final CdsEngine _cdsEngine;
  final ToolExecutor _toolExecutor;

  // Using CactusLM from pub.dev package for model loading
  cactus.CactusLM? _routingLM;     // FunctionGemma for tool calling
  cactus.CactusLM? _reasoningLM;   // LFM for reasoning

  String? _routingModelName;       // Model name for routing
  String? _reasoningModelName;     // Model name for reasoning

  bool _initialized = false;
  bool _modelsInitializing = false;

  // === CACHING FOR PERFORMANCE ===
  // Cache patient manifest (doesn't change within session)
  final Map<String, Map<String, dynamic>> _manifestCache = {};

  // Cache fetched FHIR data per patient (medications, conditions, etc.)
  final Map<String, Map<String, dynamic>> _dataCache = {};

  // Track which patients have had CDS check run (only run once per session)
  final Set<String> _cdsCheckedPatients = {};

  // Cache CDS alerts per patient
  final Map<String, List<CdsAlert>> _alertsCache = {};

  EhrAgentService({
    FhirQueryService? fhirService,
    CdsEngine? cdsEngine,
  })  : _fhirService = fhirService ?? FhirQueryService(),
        _cdsEngine = cdsEngine ?? CdsEngine(),
        _toolExecutor = ToolExecutor(
          fhirService: fhirService ?? FhirQueryService(),
          cdsEngine: cdsEngine ?? CdsEngine(),
        );

  /// Initialize the agent with models from the Cactus registry
  /// Uses CactusLM from pub.dev package for model loading
  Future<bool> initialize({
    String? routingModelName,
    String? reasoningModelName,
    Function(double progress, String status)? onProgress,
    // Legacy parameters (ignored)
    String? routingModelPath,
    String? reasoningModelPath,
  }) async {
    if (_modelsInitializing) return false;
    _modelsInitializing = true;

    try {
      await _fhirService.initialize();

      // Enable NPU acceleration with Pro key
      cactus.CactusConfig.setProKey('cactus_live_2394695b111a3a4b9e72ccb46b2bc184');
      debugPrint('NPU acceleration enabled with Pro key');

      // Use provided model names or defaults
      // Using qwen3-0.6 for both routing and reasoning
      _routingModelName = routingModelName ?? 'qwen3-0.6';
      _reasoningModelName = reasoningModelName ?? 'qwen3-0.6';

      // Initialize routing model (FunctionGemma for tool calling)
      try {
        debugPrint('Initializing routing model: $_routingModelName');
        onProgress?.call(0.1, 'Loading routing model...');

        _routingLM = cactus.CactusLM();
        await _routingLM!.downloadModel(
          model: _routingModelName!,
          downloadProcessCallback: (progress, status, isError) {
            if (!isError) {
              onProgress?.call((progress ?? 0) * 0.4, status);
            }
          },
        );
        await _routingLM!.initializeModel(
          params: cactus.CactusInitParams(model: _routingModelName!),
        );
        debugPrint('Routing model initialized successfully');
      } catch (e) {
        debugPrint('Routing model init failed: $e - will use keyword routing');
        _routingLM?.unload();
        _routingLM = null;
      }

      // Initialize reasoning model (LFM for medical reasoning)
      try {
        debugPrint('Initializing reasoning model: $_reasoningModelName');
        onProgress?.call(0.5, 'Loading reasoning model...');

        _reasoningLM = cactus.CactusLM();
        await _reasoningLM!.downloadModel(
          model: _reasoningModelName!,
          downloadProcessCallback: (progress, status, isError) {
            if (!isError) {
              onProgress?.call(0.4 + (progress ?? 0) * 0.5, status);
            }
          },
        );
        await _reasoningLM!.initializeModel(
          params: cactus.CactusInitParams(model: _reasoningModelName!),
        );
        debugPrint('Reasoning model initialized successfully');
      } catch (e) {
        debugPrint('Reasoning model init failed: $e - will use simple synthesis');
        _reasoningLM?.unload();
        _reasoningLM = null;
      }

      onProgress?.call(1.0, 'Models ready');
      _initialized = true;
      _modelsInitializing = false;
      return _routingLM != null || _reasoningLM != null;
    } catch (e) {
      debugPrint('Failed to initialize EhrAgentService: $e');
      _modelsInitializing = false;
      return false;
    }
  }

  /// Check if models are available
  bool get hasModels => _routingLM != null || _reasoningLM != null;
  bool get hasRoutingModel => _routingLM != null;
  bool get hasReasoningModel => _reasoningLM != null;

  /// Clear caches for a specific patient (call when patient data changes)
  void clearCacheForPatient(String patientId) {
    _manifestCache.remove(patientId);
    _dataCache.remove(patientId);
    _cdsCheckedPatients.remove(patientId);
    _alertsCache.remove(patientId);
  }

  /// Clear all caches
  void clearAllCaches() {
    _manifestCache.clear();
    _dataCache.clear();
    _cdsCheckedPatients.clear();
    _alertsCache.clear();
  }

  /// Process a user query about a patient
  /// Returns a stream of AgentState updates
  Stream<AgentState> processQuery(String patientId, String query) async* {
    var state = AgentState(
      patientId: patientId,
      query: query,
      phase: AgentPhase.idle,
    );

    final startTime = DateTime.now();

    // Only reset KV cache on first query for this patient, not subsequent queries
    // This allows faster inference by reusing cached context
    final isFirstQueryForPatient = !_manifestCache.containsKey(patientId);
    if (isFirstQueryForPatient) {
      _routingLM?.reset();
      _reasoningLM?.reset();
    }

    try {
      // Phase 1: Discovery - Get patient manifest (use cache if available)
      state = state.copyWith(phase: AgentPhase.discovery);

      Map<String, dynamic> manifest;
      Map<String, List<String>> availableResources;

      if (_manifestCache.containsKey(patientId)) {
        // Use cached manifest - skip discovery phase quickly
        manifest = _manifestCache[patientId]!;
        availableResources = (manifest['availableResources'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, (v['codes'] as List<dynamic>?)?.cast<String>() ?? <String>[])) ?? {};
        state = state.addStep(AgentStep(
          phase: AgentPhase.discovery,
          description: 'Using cached patient data (${availableResources.length} resource types)',
          data: {'resources': availableResources.keys.toList(), 'cached': true},
        ));
      } else {
        // First query - fetch and cache manifest
        state = state.addStep(AgentStep(
          phase: AgentPhase.discovery,
          description: 'Discovering available patient data...',
        ));
        yield state;

        manifest = await _fhirService.getPatientManifest(patientId);
        _manifestCache[patientId] = manifest; // Cache it
        availableResources = (manifest['availableResources'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, (v['codes'] as List<dynamic>?)?.cast<String>() ?? <String>[])) ?? {};
        state = state.addStep(AgentStep(
          phase: AgentPhase.discovery,
          description: 'Found ${availableResources.length} resource types',
          data: {'resources': availableResources.keys.toList()},
        ));
      }

      state = state.copyWith(availableResources: availableResources);
      yield state;

      // Phase 2: Routing - Select tools based on query
      state = state.copyWith(phase: AgentPhase.routing);
      state = state.addStep(AgentStep(
        phase: AgentPhase.routing,
        description: 'Planning which data to retrieve...',
      ));
      yield state;

      final toolCalls = await _planTools(query, availableResources, patientId);
      state = state.copyWith(plannedToolCalls: toolCalls);
      state = state.addStep(AgentStep(
        phase: AgentPhase.routing,
        description: 'Selected ${toolCalls.length} tools',
        data: {'tools': toolCalls.map((t) => t.name).toList()},
      ));
      yield state;

      // Phase 3: Execute - Fetch FHIR data (use cache when possible)
      state = state.copyWith(phase: AgentPhase.executing);

      // Initialize patient data cache if needed
      _dataCache[patientId] ??= {};
      final patientDataCache = _dataCache[patientId]!;

      final fetchedData = <String, dynamic>{};
      final toolsToExecute = <ToolCall>[];
      int cachedCount = 0;

      // Check which tools have cached results
      for (final toolCall in toolCalls) {
        final cacheKey = '${toolCall.name}_${toolCall.arguments.toString()}';
        if (patientDataCache.containsKey(cacheKey)) {
          fetchedData[toolCall.name] = patientDataCache[cacheKey];
          cachedCount++;
        } else {
          toolsToExecute.add(toolCall);
        }
      }

      if (toolsToExecute.isEmpty) {
        // All data from cache - fast path
        state = state.addStep(AgentStep(
          phase: AgentPhase.executing,
          description: 'Using cached records ($cachedCount items)',
          data: {'cached': true, 'count': cachedCount},
        ));
      } else {
        state = state.addStep(AgentStep(
          phase: AgentPhase.executing,
          description: 'Fetching ${toolsToExecute.length} records${cachedCount > 0 ? ' ($cachedCount cached)' : ''}...',
        ));
        yield state;

        // Execute only tools without cached results
        for (final toolCall in toolsToExecute) {
          final result = await _toolExecutor.execute(toolCall);
          state = state.addToolResult(result);
          fetchedData[toolCall.name] = result.result;
          // Cache the result
          final cacheKey = '${toolCall.name}_${toolCall.arguments.toString()}';
          patientDataCache[cacheKey] = result.result;
          yield state;
        }
      }

      state = state.copyWith(fetchedData: fetchedData);

      // Phase 4: Filter - Extract relevant facts
      state = state.copyWith(phase: AgentPhase.filtering);
      state = state.addStep(AgentStep(
        phase: AgentPhase.filtering,
        description: 'Extracting relevant facts...',
      ));
      yield state;

      final facts = await _extractFacts(query, fetchedData);
      state = state.copyWith(collectedFacts: facts);
      state = state.addStep(AgentStep(
        phase: AgentPhase.filtering,
        description: 'Extracted ${facts.length} relevant facts',
      ));
      yield state;

      // Phase 5: CDS Check - Run clinical decision support (skip if already done)
      state = state.copyWith(phase: AgentPhase.cdsChecking);

      List<CdsAlert> alerts;

      if (_cdsCheckedPatients.contains(patientId)) {
        // Already ran CDS for this patient - use cached alerts
        alerts = _alertsCache[patientId] ?? [];
        state = state.addStep(AgentStep(
          phase: AgentPhase.cdsChecking,
          description: alerts.isEmpty
              ? 'Safety checks already completed'
              : 'Using cached alerts (${alerts.length} active)',
          data: {'cached': true},
        ));
      } else {
        // First time - run CDS checks
        state = state.addStep(AgentStep(
          phase: AgentPhase.cdsChecking,
          description: 'Running clinical safety checks...',
        ));
        yield state;

        alerts = await _toolExecutor.runCdsChecks(patientId);
        _cdsCheckedPatients.add(patientId);
        _alertsCache[patientId] = alerts;

        if (alerts.isNotEmpty) {
          state = state.addStep(AgentStep(
            phase: AgentPhase.cdsChecking,
            description: 'Found ${alerts.length} clinical alerts',
            data: {'alertTypes': alerts.map((a) => a.type.name).toList()},
          ));
        }
      }

      state = state.copyWith(alerts: alerts);
      yield state;

      // Phase 6: Synthesize - Generate response with STREAMING
      state = state.copyWith(phase: AgentPhase.synthesizing);
      state = state.addStep(AgentStep(
        phase: AgentPhase.synthesizing,
        description: 'Generating response...',
      ));
      yield state;

      // Use streaming if model is available for real-time token output
      if (_reasoningLM != null) {
        final buffer = StringBuffer();
        await for (final token in _synthesizeWithModelStreaming(query, facts, alerts)) {
          buffer.write(token);
          // Yield intermediate state with partial response for streaming UI
          state = state.copyWith(response: buffer.toString());
          yield state;
        }
        // Parse final response to extract thinking
        final parsed = _parseModelOutput(buffer.toString());
        state = state.copyWith(
          phase: AgentPhase.complete,
          response: parsed.response,
          thinking: parsed.thinking,
          endTime: DateTime.now(),
        );
      } else {
        // Non-streaming fallback
        final synthesisResult = await _synthesizeResponse(query, facts, alerts, fetchedData);
        state = state.copyWith(
          phase: AgentPhase.complete,
          response: synthesisResult.response,
          thinking: synthesisResult.thinking,
          endTime: DateTime.now(),
        );
      }

      state = state.addStep(AgentStep(
        phase: AgentPhase.complete,
        description: 'Response generated',
        duration: DateTime.now().difference(startTime),
      ));
      yield state;

    } catch (e) {
      state = state.copyWith(
        phase: AgentPhase.error,
        error: e.toString(),
        endTime: DateTime.now(),
      );
      state = state.addStep(AgentStep(
        phase: AgentPhase.error,
        description: 'Error: $e',
      ));
      yield state;
    }
  }

  /// Plan which tools to use based on the query
  /// Always uses model when available for best results
  Future<List<ToolCall>> _planTools(
    String query,
    Map<String, List<String>> availableResources,
    String patientId,
  ) async {
    // Always use model routing when available
    if (_routingLM != null) {
      debugPrint('Using FunctionGemma for routing');
      return _planToolsWithModel(query, availableResources, patientId);
    }

    // Fall back to keyword routing only if no model
    debugPrint('No routing model - using keyword fallback');
    return _planToolsKeywordBased(query, patientId);
  }

  /// Plan tools using the routing model
  /// Uses CactusLM from pub.dev package with generateCompletion()
  Future<List<ToolCall>> _planToolsWithModel(
    String query,
    Map<String, List<String>> availableResources,
    String patientId,
  ) async {
    final systemPrompt = '''You are an EHR navigation assistant. Based on the user's question, select which tools to call to retrieve relevant patient data.

Available resources for this patient: ${availableResources.keys.join(', ')}

${ToolRegistry.getToolsSummary()}

Always call a tool. If unsure, call get_patient_info.''';

    try {
      final messages = [
        cactus.ChatMessage(role: 'system', content: systemPrompt),
        cactus.ChatMessage(role: 'user', content: query),
      ];

      // Use CactusLM generateCompletion with tools
      final result = await _routingLM!.generateCompletion(
        messages: messages,
        params: cactus.CactusCompletionParams(
          maxTokens: 256,
          temperature: 0.0,
          tools: ToolRegistry.getTools(),
        ),
      );

      debugPrint('Routing result: text=${result.response.length} chars, toolCalls=${result.toolCalls.length}');

      // Parse tool calls from result
      if (result.toolCalls.isNotEmpty) {
        return result.toolCalls.map((tc) => ToolCall(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: tc.name,
          arguments: {
            ...tc.arguments.map((k, v) => MapEntry(k, v)),
            'patient_id': patientId,
          },
        )).toList();
      }

      // Try to parse JSON from text response as fallback
      final text = _cleanModelResponse(result.response);
      if (text.startsWith('[')) {
        try {
          final parsed = jsonDecode(text) as List<dynamic>;
          return parsed.map((tc) => ToolCall(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: tc['name'] as String,
            arguments: {
              ...(tc['arguments'] as Map<String, dynamic>? ?? {}),
              'patient_id': patientId,
            },
          )).toList();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Model routing failed, falling back to keyword: $e');
    }

    return _planToolsKeywordBased(query, patientId);
  }

  /// Plan tools using keyword-based routing (fallback)
  List<ToolCall> _planToolsKeywordBased(String query, String patientId) {
    final queryLower = query.toLowerCase();
    final tools = <ToolCall>[];

    // Medication queries
    if (queryLower.contains('medication') ||
        queryLower.contains('drug') ||
        queryLower.contains('prescription') ||
        queryLower.contains('taking') ||
        queryLower.contains('medicine')) {
      tools.add(ToolCall(
        id: '${DateTime.now().millisecondsSinceEpoch}_meds',
        name: 'get_medications',
        arguments: {'patient_id': patientId, 'status': 'active'},
      ));
    }

    // Condition queries
    if (queryLower.contains('condition') ||
        queryLower.contains('diagnosis') ||
        queryLower.contains('disease') ||
        queryLower.contains('problem') ||
        queryLower.contains('diabetes') ||
        queryLower.contains('hypertension') ||
        queryLower.contains('controlled')) {
      tools.add(ToolCall(
        id: '${DateTime.now().millisecondsSinceEpoch}_cond',
        name: 'get_conditions',
        arguments: {'patient_id': patientId},
      ));
    }

    // Lab/observation queries
    if (queryLower.contains('lab') ||
        queryLower.contains('test') ||
        queryLower.contains('result') ||
        queryLower.contains('vital') ||
        queryLower.contains('blood') ||
        queryLower.contains('hba1c') ||
        queryLower.contains('glucose')) {
      tools.add(ToolCall(
        id: '${DateTime.now().millisecondsSinceEpoch}_obs',
        name: 'get_observations',
        arguments: {'patient_id': patientId},
      ));
    }

    // Allergy queries
    if (queryLower.contains('allergy') ||
        queryLower.contains('allergic') ||
        queryLower.contains('intolerance') ||
        queryLower.contains('reaction')) {
      tools.add(ToolCall(
        id: '${DateTime.now().millisecondsSinceEpoch}_allergy',
        name: 'get_allergies',
        arguments: {'patient_id': patientId},
      ));
    }

    // Visit/encounter queries
    if (queryLower.contains('visit') ||
        queryLower.contains('encounter') ||
        queryLower.contains('hospital') ||
        queryLower.contains('admission')) {
      tools.add(ToolCall(
        id: '${DateTime.now().millisecondsSinceEpoch}_enc',
        name: 'get_encounters',
        arguments: {'patient_id': patientId, 'limit': 5},
      ));
    }

    // Drug interaction queries
    if (queryLower.contains('interaction') ||
        queryLower.contains('safe') ||
        queryLower.contains('contraindication')) {
      tools.add(ToolCall(
        id: '${DateTime.now().millisecondsSinceEpoch}_interact',
        name: 'check_drug_interactions',
        arguments: {'patient_id': patientId},
      ));
    }

    // Trend queries - vitals
    if (queryLower.contains('trend') ||
        queryLower.contains('over time') ||
        queryLower.contains('history of') ||
        queryLower.contains('blood pressure trend') ||
        queryLower.contains('weight trend') ||
        queryLower.contains('vital trend')) {
      tools.add(ToolCall(
        id: '${DateTime.now().millisecondsSinceEpoch}_vital_trends',
        name: 'get_vital_trends',
        arguments: {'patient_id': patientId},
      ));
    }

    // Trend queries - labs
    if (queryLower.contains('lab trend') ||
        queryLower.contains('glucose trend') ||
        queryLower.contains('a1c trend') ||
        queryLower.contains('hba1c trend') ||
        queryLower.contains('cholesterol trend') ||
        queryLower.contains('kidney trend') ||
        queryLower.contains('creatinine trend')) {
      tools.add(ToolCall(
        id: '${DateTime.now().millisecondsSinceEpoch}_lab_trends',
        name: 'get_lab_trends',
        arguments: {'patient_id': patientId},
      ));
    }

    // Critical results / abnormal labs
    if (queryLower.contains('critical') ||
        queryLower.contains('abnormal') ||
        queryLower.contains('out of range') ||
        queryLower.contains('flagged') ||
        queryLower.contains('concerning')) {
      tools.add(ToolCall(
        id: '${DateTime.now().millisecondsSinceEpoch}_critical',
        name: 'get_critical_results',
        arguments: {'patient_id': patientId},
      ));
    }

    // Care gaps / overdue screenings
    if (queryLower.contains('screening') ||
        queryLower.contains('overdue') ||
        queryLower.contains('care gap') ||
        queryLower.contains('due for') ||
        queryLower.contains('preventive') ||
        queryLower.contains('need to check')) {
      tools.add(ToolCall(
        id: '${DateTime.now().millisecondsSinceEpoch}_screenings',
        name: 'check_overdue_screenings',
        arguments: {'patient_id': patientId},
      ));
    }

    // Immunizations / vaccinations
    if (queryLower.contains('immunization') ||
        queryLower.contains('vaccination') ||
        queryLower.contains('vaccine') ||
        queryLower.contains('shot') ||
        queryLower.contains('immunized')) {
      tools.add(ToolCall(
        id: '${DateTime.now().millisecondsSinceEpoch}_imm',
        name: 'get_immunizations',
        arguments: {'patient_id': patientId},
      ));
    }

    // Recent visits / handoff
    if (queryLower.contains('recent visit') ||
        queryLower.contains('last visit') ||
        queryLower.contains('handoff') ||
        queryLower.contains('hand off') ||
        queryLower.contains('shift change') ||
        queryLower.contains('what happened') ||
        queryLower.contains('recent encounter')) {
      tools.add(ToolCall(
        id: '${DateTime.now().millisecondsSinceEpoch}_visits',
        name: 'get_recent_visits',
        arguments: {'patient_id': patientId, 'limit': 5},
      ));
    }

    // General patient info
    if (tools.isEmpty ||
        queryLower.contains('who is') ||
        queryLower.contains('patient info') ||
        queryLower.contains('summary')) {
      tools.add(ToolCall(
        id: '${DateTime.now().millisecondsSinceEpoch}_info',
        name: 'get_patient_info',
        arguments: {'patient_id': patientId},
      ));
      // Add conditions and medications for a summary
      if (!tools.any((t) => t.name == 'get_conditions')) {
        tools.add(ToolCall(
          id: '${DateTime.now().millisecondsSinceEpoch}_cond',
          name: 'get_conditions',
          arguments: {'patient_id': patientId},
        ));
      }
      if (!tools.any((t) => t.name == 'get_medications')) {
        tools.add(ToolCall(
          id: '${DateTime.now().millisecondsSinceEpoch}_meds',
          name: 'get_medications',
          arguments: {'patient_id': patientId, 'status': 'active'},
        ));
      }
    }

    return tools;
  }

  /// Extract relevant facts from fetched data
  /// Always uses LFM when available for best results
  Future<List<String>> _extractFacts(
    String query,
    Map<String, dynamic> fetchedData,
  ) async {
    // Always use model extraction when available
    if (_reasoningLM != null) {
      debugPrint('Using LFM for fact extraction');
      return _extractFactsWithModel(query, fetchedData);
    }

    // Fall back to simple extraction only if no model
    debugPrint('No reasoning model - using simple extraction');
    return _extractFactsSimple(fetchedData);
  }

  /// Extract facts using the reasoning model (LFM)
  /// Uses CactusLM from pub.dev package with generateCompletion()
  Future<List<String>> _extractFactsWithModel(
    String query,
    Map<String, dynamic> fetchedData,
  ) async {
    final facts = <String>[];

    for (final entry in fetchedData.entries) {
      final prompt = '''Extract relevant facts from this medical data to answer: "$query"

Data source: ${entry.key}
Data: ${jsonEncode(entry.value)}

List only the facts relevant to the question, one per line. Be concise.''';

      try {
        final messages = [
          cactus.ChatMessage(role: 'system', content: 'You are a medical data analyst. Extract key facts concisely.'),
          cactus.ChatMessage(role: 'user', content: prompt),
        ];

        // Use CactusLM generateCompletion
        final result = await _reasoningLM!.generateCompletion(
          messages: messages,
          params: cactus.CactusCompletionParams(
            maxTokens: 256,
            temperature: 0.3,
          ),
        );

        final cleaned = _cleanModelResponse(result.response);
        final extractedFacts = cleaned
            .split('\n')
            .map((f) => _cleanModelResponse(f.trim()))  // Clean each line too
            .where((f) => f.isNotEmpty)
            .map((f) => f.startsWith('- ') ? f.substring(2) : f)
            .toList();
        facts.addAll(extractedFacts);
      } catch (e) {
        debugPrint('Fact extraction failed for ${entry.key}: $e');
        facts.addAll(_extractFactsFromResult(entry.key, entry.value));
      }
    }

    return facts;
  }

  /// Extract facts without model (simple extraction)
  List<String> _extractFactsSimple(Map<String, dynamic> fetchedData) {
    final facts = <String>[];
    for (final entry in fetchedData.entries) {
      facts.addAll(_extractFactsFromResult(entry.key, entry.value));
    }
    return facts;
  }

  /// Extract facts from a single tool result
  List<String> _extractFactsFromResult(String toolName, dynamic result) {
    final facts = <String>[];
    if (result is! Map<String, dynamic>) return facts;

    switch (toolName) {
      case 'get_patient_info':
        if (result['name'] != null) facts.add('Patient: ${result['name']}');
        if (result['age'] != null) facts.add('Age: ${result['age']} years');
        if (result['gender'] != null) facts.add('Gender: ${result['gender']}');
        break;

      case 'get_conditions':
        final conditions = result['conditions'] as List<dynamic>? ?? [];
        for (final c in conditions.take(5)) {
          final cond = c as Map<String, dynamic>;
          final status = cond['isActive'] == true ? 'active' : 'resolved';
          facts.add('Condition: ${cond['name']} ($status)');
        }
        break;

      case 'get_medications':
        final meds = result['medications'] as List<dynamic>? ?? [];
        for (final m in meds.take(5)) {
          final med = m as Map<String, dynamic>;
          facts.add('Medication: ${med['name']} - ${med['dosage'] ?? 'dosage not specified'}');
        }
        break;

      case 'get_observations':
        final obs = result['observations'] as List<dynamic>? ?? [];
        for (final o in obs.take(5)) {
          final ob = o as Map<String, dynamic>;
          facts.add('${ob['name']}: ${ob['value']} ${ob['unit'] ?? ''}');
        }
        break;

      case 'get_allergies':
        final allergies = result['allergies'] as List<dynamic>? ?? [];
        for (final a in allergies) {
          final allergy = a as Map<String, dynamic>;
          final crit = allergy['isHighCriticality'] == true ? ' (HIGH RISK)' : '';
          facts.add('Allergy: ${allergy['allergen']}$crit');
        }
        break;

      case 'get_encounters':
        final encounters = result['encounters'] as List<dynamic>? ?? [];
        for (final e in encounters.take(3)) {
          final enc = e as Map<String, dynamic>;
          facts.add('Visit: ${enc['summary']} - ${enc['reason'] ?? 'reason not specified'}');
        }
        break;

      case 'check_drug_interactions':
        final alerts = result['alerts'] as List<dynamic>? ?? [];
        if (alerts.isEmpty) {
          facts.add('No drug interactions detected');
        } else {
          for (final a in alerts) {
            final alert = a as Map<String, dynamic>;
            facts.add('INTERACTION: ${alert['title']}');
          }
        }
        break;

      case 'get_vital_trends':
        final statistics = result['statistics'] as Map<String, dynamic>? ?? {};
        for (final entry in statistics.entries.take(5)) {
          final stat = entry.value as Map<String, dynamic>;
          final display = stat['display'] ?? entry.key;
          final latest = stat['latest'];
          final unit = stat['unit'] ?? '';
          final trend = stat['trend'] ?? 'unknown';
          facts.add('$display: latest $latest $unit (trend: $trend)');
        }
        break;

      case 'get_lab_trends':
        final statistics = result['statistics'] as Map<String, dynamic>? ?? {};
        for (final entry in statistics.entries.take(5)) {
          final stat = entry.value as Map<String, dynamic>;
          final display = stat['display'] ?? entry.key;
          final latest = stat['latest'];
          final unit = stat['unit'] ?? '';
          final isAbnormal = stat['latestAbnormal'] == true;
          final abnormalMarker = isAbnormal ? ' (ABNORMAL)' : '';
          facts.add('Lab $display: $latest $unit$abnormalMarker');
        }
        break;

      case 'get_critical_results':
        final urgent = result['urgent'] as Map<String, dynamic>? ?? {};
        final urgentResults = urgent['results'] as List<dynamic>? ?? [];
        if (urgentResults.isNotEmpty) {
          facts.add('URGENT: ${urgentResults.length} abnormal results in last 7 days');
          for (final r in urgentResults.take(3)) {
            final res = r as Map<String, dynamic>;
            facts.add('Critical: ${res['name']}: ${res['value']}');
          }
        }
        final recent = result['recent'] as Map<String, dynamic>? ?? {};
        final recentResults = recent['results'] as List<dynamic>? ?? [];
        if (recentResults.isNotEmpty) {
          facts.add('${recentResults.length} abnormal results in last 30 days');
        }
        if (urgentResults.isEmpty && recentResults.isEmpty) {
          facts.add('No critical lab results requiring immediate attention');
        }
        break;

      case 'check_overdue_screenings':
        final careGaps = result['careGaps'] as List<dynamic>? ?? [];
        if (careGaps.isEmpty) {
          facts.add('No overdue screenings identified');
        } else {
          facts.add('${careGaps.length} care gaps identified');
          for (final gap in careGaps.take(5)) {
            final g = gap as Map<String, dynamic>;
            final priority = g['priority'] ?? 'medium';
            final priorityMarker = priority == 'high' ? ' (HIGH PRIORITY)' : '';
            facts.add('Overdue: ${g['screening']}$priorityMarker');
          }
        }
        break;

      case 'get_immunizations':
        final immunizations = result['immunizations'] as List<dynamic>? ?? [];
        final count = result['count'] ?? immunizations.length;
        facts.add('$count immunizations on record');
        for (final imm in immunizations.take(5)) {
          final i = imm as Map<String, dynamic>;
          facts.add('Vaccine: ${i['vaccine']} (${i['date']?.toString().substring(0, 10) ?? 'date unknown'})');
        }
        break;

      case 'get_recent_visits':
        final visits = result['visits'] as List<dynamic>? ?? [];
        if (visits.isEmpty) {
          facts.add('No recent visits on record');
        } else {
          facts.add('${visits.length} recent visits');
          for (final v in visits.take(3)) {
            final visit = v as Map<String, dynamic>;
            final date = visit['startDate']?.toString().substring(0, 10) ?? 'unknown';
            facts.add('Visit $date: ${visit['type']} - ${visit['reason'] ?? visit['summary']}');
          }
        }
        break;
    }

    return facts;
  }

  /// Synthesize the final response
  /// Always uses LFM when available for natural language responses
  /// Returns ParsedModelOutput with both response and optional thinking
  Future<ParsedModelOutput> _synthesizeResponse(
    String query,
    List<String> facts,
    List<CdsAlert> alerts,
    Map<String, dynamic> fetchedData,
  ) async {
    // Always use model synthesis when available
    if (_reasoningLM != null) {
      debugPrint('Using LFM for response synthesis');
      return _synthesizeWithModel(query, facts, alerts);
    }

    // Fall back to simple synthesis only if no model
    debugPrint('No reasoning model - using simple synthesis');
    return ParsedModelOutput(response: _synthesizeSimple(query, facts, alerts));
  }

  /// Synthesize response using the reasoning model (LFM) with STREAMING
  /// Yields partial responses as tokens are generated for better UX
  Stream<String> _synthesizeWithModelStreaming(
    String query,
    List<String> facts,
    List<CdsAlert> alerts,
  ) async* {
    // Note: Alerts are shown in persistent UI banner, not in response text
    final prompt = '''Based on the following patient data, answer this question: "$query"

COLLECTED FACTS:
${facts.map((f) => '- $f').join('\n')}

Provide a clear, concise answer based only on the facts above. Do not mention clinical alerts or warnings - those are shown separately.''';

    final messages = [
      cactus.ChatMessage(
        role: 'system',
        content: '''You are a medical assistant helping clinicians understand patient data.
Be concise and accurate. Highlight any safety concerns prominently.
Do not provide medical advice or diagnosis - just present the data clearly.''',
      ),
      cactus.ChatMessage(role: 'user', content: prompt),
    ];

    try {
      // Use streaming completion for real-time token output
      final streamedResult = await _reasoningLM!.generateCompletionStream(
        messages: messages,
        params: cactus.CactusCompletionParams(
          maxTokens: 512,
          temperature: 0.5,
        ),
      );

      // Yield tokens as they arrive
      await for (final token in streamedResult.stream) {
        yield token;
      }

      // Log final metrics
      final result = await streamedResult.result;
      debugPrint('═══════════════════════════════════════');
      debugPrint('📊 STREAMING METRICS (NPU: ${result.tokensPerSecond > 50 ? "likely" : "unlikely"})');
      debugPrint('   Tokens/sec: ${result.tokensPerSecond.toStringAsFixed(1)}');
      debugPrint('   Time to first token: ${result.timeToFirstTokenMs.toStringAsFixed(0)}ms');
      debugPrint('   Total time: ${result.totalTimeMs.toStringAsFixed(0)}ms');
      debugPrint('═══════════════════════════════════════');
    } catch (e) {
      debugPrint('Streaming synthesis failed: $e');
      yield _synthesizeSimple(query, facts, alerts);
    }
  }

  /// Synthesize response using the reasoning model (LFM)
  /// Uses CactusLM from pub.dev package with generateCompletion()
  /// Returns ParsedModelOutput with response and optional thinking
  Future<ParsedModelOutput> _synthesizeWithModel(
    String query,
    List<String> facts,
    List<CdsAlert> alerts,
  ) async {
    // Note: Alerts are shown in persistent UI banner, not in response text
    final prompt = '''Based on the following patient data, answer this question: "$query"

COLLECTED FACTS:
${facts.map((f) => '- $f').join('\n')}

Provide a clear, concise answer based only on the facts above. Do not mention clinical alerts or warnings - those are shown separately.''';

    try {
      final messages = [
        cactus.ChatMessage(
          role: 'system',
          content: '''You are a medical assistant helping clinicians understand patient data.
Be concise and accurate. Highlight any safety concerns prominently.
Do not provide medical advice or diagnosis - just present the data clearly.''',
        ),
        cactus.ChatMessage(role: 'user', content: prompt),
      ];

      // Use CactusLM generateCompletion
      final result = await _reasoningLM!.generateCompletion(
        messages: messages,
        params: cactus.CactusCompletionParams(
          maxTokens: 512,
          temperature: 0.5,
        ),
      );

      // Log performance metrics
      debugPrint('═══════════════════════════════════════');
      debugPrint('📊 INFERENCE METRICS (NPU: ${result.tokensPerSecond > 50 ? "likely" : "unlikely"})');
      debugPrint('   Tokens/sec: ${result.tokensPerSecond.toStringAsFixed(1)}');
      debugPrint('   Time to first token: ${result.timeToFirstTokenMs.toStringAsFixed(0)}ms');
      debugPrint('   Total time: ${result.totalTimeMs.toStringAsFixed(0)}ms');
      debugPrint('   Tokens: ${result.prefillTokens} prefill + ${result.decodeTokens} decode');
      debugPrint('═══════════════════════════════════════');

      // Parse output to extract thinking separately
      final parsed = _parseModelOutput(result.response);

      // If response is empty, fall back to simple synthesis
      if (parsed.response.isEmpty) {
        debugPrint('Model returned empty response after parsing, using simple synthesis');
        return ParsedModelOutput(response: _synthesizeSimple(query, facts, alerts));
      }
      return parsed;
    } catch (e) {
      debugPrint('Synthesis with model failed: $e');
      return ParsedModelOutput(response: _synthesizeSimple(query, facts, alerts));
    }
  }

  /// Synthesize response without model
  /// Note: Alerts are shown in persistent UI bar, not in response text
  String _synthesizeSimple(
    String query,
    List<String> facts,
    List<CdsAlert> alerts,
  ) {
    if (facts.isEmpty) {
      return 'No relevant information found for this query.';
    }

    final buffer = StringBuffer();
    final queryLower = query.toLowerCase();

    // Group facts by type for cleaner presentation
    final medications = facts.where((f) => f.startsWith('Medication:')).toList();
    final conditions = facts.where((f) => f.startsWith('Condition:')).toList();
    final observations = facts.where((f) => !f.startsWith('Medication:') && !f.startsWith('Condition:') && !f.startsWith('Patient:') && !f.startsWith('Age:') && !f.startsWith('Gender:') && !f.startsWith('INTERACTION:') && !f.startsWith('Allergy:') && !f.startsWith('Visit:')).toList();
    final interactions = facts.where((f) => f.startsWith('INTERACTION:') || f.contains('No drug interactions')).toList();
    final allergies = facts.where((f) => f.startsWith('Allergy:')).toList();
    final visits = facts.where((f) => f.startsWith('Visit:')).toList();
    final patientInfo = facts.where((f) => f.startsWith('Patient:') || f.startsWith('Age:') || f.startsWith('Gender:')).toList();

    // Medications query
    if (queryLower.contains('medication') || queryLower.contains('drug') || queryLower.contains('taking')) {
      if (medications.isNotEmpty) {
        buffer.writeln('**Current Medications:**');
        for (final med in medications) {
          buffer.writeln('- ${med.replaceFirst('Medication: ', '')}');
        }
      } else {
        buffer.writeln('No medications found in the patient records.');
      }
    }
    // Conditions query
    else if (queryLower.contains('condition') || queryLower.contains('diagnosis') || queryLower.contains('problem')) {
      if (conditions.isNotEmpty) {
        buffer.writeln('**Conditions:**');
        for (final cond in conditions) {
          buffer.writeln('- ${cond.replaceFirst('Condition: ', '')}');
        }
      } else {
        buffer.writeln('No conditions found in the patient records.');
      }
    }
    // Drug interactions query
    else if (queryLower.contains('interaction')) {
      if (interactions.isNotEmpty) {
        for (final interaction in interactions) {
          if (interaction.contains('No drug interactions')) {
            buffer.writeln('No drug interactions detected.');
          } else {
            buffer.writeln('**Warning:** ${interaction.replaceFirst('INTERACTION: ', '')}');
          }
        }
      } else {
        buffer.writeln('No drug interaction data available.');
      }
    }
    // Labs query
    else if (queryLower.contains('lab') || queryLower.contains('test') || queryLower.contains('result')) {
      if (observations.isNotEmpty) {
        buffer.writeln('**Lab Results:**');
        for (final obs in observations) {
          buffer.writeln('- $obs');
        }
      } else {
        buffer.writeln('No lab results found in the patient records.');
      }
    }
    // Allergies query
    else if (queryLower.contains('allergy') || queryLower.contains('allergic')) {
      if (allergies.isNotEmpty) {
        buffer.writeln('**Allergies:**');
        for (final allergy in allergies) {
          buffer.writeln('- ${allergy.replaceFirst('Allergy: ', '')}');
        }
      } else {
        buffer.writeln('No allergies documented.');
      }
    }
    // Default: show all facts grouped
    else {
      if (patientInfo.isNotEmpty) {
        for (final info in patientInfo) {
          buffer.writeln('- $info');
        }
        buffer.writeln();
      }
      if (conditions.isNotEmpty) {
        buffer.writeln('**Conditions:**');
        for (final cond in conditions) {
          buffer.writeln('- ${cond.replaceFirst('Condition: ', '')}');
        }
        buffer.writeln();
      }
      if (medications.isNotEmpty) {
        buffer.writeln('**Medications:**');
        for (final med in medications) {
          buffer.writeln('- ${med.replaceFirst('Medication: ', '')}');
        }
      }
    }

    return buffer.toString().trim();
  }

  /// Dispose resources
  void dispose() {
    _routingLM?.unload();
    _reasoningLM?.unload();
    _routingLM = null;
    _reasoningLM = null;
    _initialized = false;
    clearAllCaches();
  }
}
