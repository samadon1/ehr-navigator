/// ============================================
/// AGENT PIPELINE - Multi-Step Reasoning
/// ============================================
///
/// The agent processes queries through 6 phases:
/// Discovery → Routing → Executing → Filtering → CDS → Synthesizing

import 'package:cactus/cactus.dart' as cactus;

// ---------------------------------------------
// Agent Phases (State Machine)
// ---------------------------------------------
enum AgentPhase {
  idle,         // Ready for query
  discovery,    // Find available data
  routing,      // LLM selects tools
  executing,    // Fetch FHIR data
  filtering,    // LLM extracts facts
  cdsChecking,  // Safety checks
  synthesizing, // Generate response
  complete,     // Done
  error,        // Something failed
}

// ---------------------------------------------
// Agent State (Tracks Everything)
// ---------------------------------------------
class AgentState {
  final String patientId;
  final String query;
  final AgentPhase phase;

  final List<String> availableResources;  // What data exists
  final List<ToolCall> toolCalls;         // What tools to call
  final Map<String, dynamic> fetchedData; // Raw FHIR data
  final List<String> facts;               // Extracted facts
  final List<CdsAlert> alerts;            // Safety alerts
  final String? response;                 // Final answer

  AgentState({
    required this.patientId,
    required this.query,
    this.phase = AgentPhase.idle,
    this.availableResources = const [],
    this.toolCalls = const [],
    this.fetchedData = const {},
    this.facts = const [],
    this.alerts = const [],
    this.response,
  });

  AgentState copyWith({
    AgentPhase? phase,
    List<String>? availableResources,
    List<ToolCall>? toolCalls,
    Map<String, dynamic>? fetchedData,
    List<String>? facts,
    List<CdsAlert>? alerts,
    String? response,
  }) {
    return AgentState(
      patientId: patientId,
      query: query,
      phase: phase ?? this.phase,
      availableResources: availableResources ?? this.availableResources,
      toolCalls: toolCalls ?? this.toolCalls,
      fetchedData: fetchedData ?? this.fetchedData,
      facts: facts ?? this.facts,
      alerts: alerts ?? this.alerts,
      response: response ?? this.response,
    );
  }
}

// ---------------------------------------------
// Main Agent Loop (Async Generator)
// ---------------------------------------------
class EhrAgent {
  final cactus.CactusLM routingModel;   // For tool selection
  final cactus.CactusLM reasoningModel; // For synthesis
  final FhirService fhirService;
  final CdsEngine cdsEngine;

  EhrAgent({
    required this.routingModel,
    required this.reasoningModel,
    required this.fhirService,
    required this.cdsEngine,
  });

  /// Process a query - yields state updates for real-time UI
  Stream<AgentState> processQuery(String patientId, String query) async* {
    var state = AgentState(patientId: patientId, query: query);

    // ─────────────────────────────────────────
    // PHASE 1: DISCOVERY
    // Find what data exists for this patient
    // ─────────────────────────────────────────
    state = state.copyWith(phase: AgentPhase.discovery);
    yield state;

    final manifest = await fhirService.getPatientManifest(patientId);
    state = state.copyWith(
      availableResources: manifest['resourceTypes'],
    );
    yield state;

    // ─────────────────────────────────────────
    // PHASE 2: ROUTING (LLM Call #1)
    // LLM decides which tools to call
    // ─────────────────────────────────────────
    state = state.copyWith(phase: AgentPhase.routing);
    yield state;

    final toolCalls = await _planTools(query, state.availableResources);
    state = state.copyWith(toolCalls: toolCalls);
    yield state;

    // ─────────────────────────────────────────
    // PHASE 3: EXECUTING
    // Fetch FHIR data for each tool
    // ─────────────────────────────────────────
    state = state.copyWith(phase: AgentPhase.executing);
    yield state;

    final fetchedData = <String, dynamic>{};
    for (final tool in toolCalls) {
      final result = await _executeTool(tool);
      fetchedData[tool.name] = result;
      yield state;  // Update UI after each fetch
    }
    state = state.copyWith(fetchedData: fetchedData);

    // ─────────────────────────────────────────
    // PHASE 4: FILTERING (LLM Call #2)
    // Extract only relevant facts
    // ─────────────────────────────────────────
    state = state.copyWith(phase: AgentPhase.filtering);
    yield state;

    final facts = await _extractFacts(query, fetchedData);
    state = state.copyWith(facts: facts);
    yield state;

    // ─────────────────────────────────────────
    // PHASE 5: CDS CHECK
    // Run clinical decision support rules
    // ─────────────────────────────────────────
    state = state.copyWith(phase: AgentPhase.cdsChecking);
    yield state;

    final alerts = await cdsEngine.checkAll(fetchedData);
    state = state.copyWith(alerts: alerts);
    yield state;

    // ─────────────────────────────────────────
    // PHASE 6: SYNTHESIZING (LLM Call #3)
    // Generate natural language response
    // ─────────────────────────────────────────
    state = state.copyWith(phase: AgentPhase.synthesizing);
    yield state;

    final response = await _synthesize(query, facts, alerts);
    state = state.copyWith(
      phase: AgentPhase.complete,
      response: response,
    );
    yield state;
  }

  // ─────────────────────────────────────────
  // Tool Planning (LLM selects tools)
  // ─────────────────────────────────────────
  Future<List<ToolCall>> _planTools(String query, List<String> available) async {
    final result = await routingModel.generateCompletion(
      messages: [
        cactus.ChatMessage(
          role: 'system',
          content: '''Select tools based on the query.
Available: get_patient_info, get_conditions, get_medications,
get_observations, get_allergies, check_drug_interactions''',
        ),
        cactus.ChatMessage(role: 'user', content: query),
      ],
      params: cactus.CactusCompletionParams(
        tools: ToolRegistry.tools,
        temperature: 0.0,
      ),
    );

    return result.toolCalls.map((tc) => ToolCall(
      name: tc.name,
      arguments: tc.arguments,
    )).toList();
  }

  // ─────────────────────────────────────────
  // Tool Execution (Fetch FHIR data)
  // ─────────────────────────────────────────
  Future<Map<String, dynamic>> _executeTool(ToolCall tool) async {
    switch (tool.name) {
      case 'get_conditions':
        return fhirService.getConditions(tool.arguments['patient_id']);
      case 'get_medications':
        return fhirService.getMedications(tool.arguments['patient_id']);
      case 'get_observations':
        return fhirService.getObservations(tool.arguments['patient_id']);
      default:
        return {};
    }
  }

  // ─────────────────────────────────────────
  // Fact Extraction (LLM filters data)
  // ─────────────────────────────────────────
  Future<List<String>> _extractFacts(String query, Map<String, dynamic> data) async {
    final result = await reasoningModel.generateCompletion(
      messages: [
        cactus.ChatMessage(
          role: 'system',
          content: 'Extract facts relevant to answering the query.',
        ),
        cactus.ChatMessage(
          role: 'user',
          content: 'Query: $query\n\nData: $data\n\nExtract relevant facts:',
        ),
      ],
    );

    return result.response.split('\n').where((f) => f.isNotEmpty).toList();
  }

  // ─────────────────────────────────────────
  // Response Synthesis (Final answer)
  // ─────────────────────────────────────────
  Future<String> _synthesize(String query, List<String> facts, List<CdsAlert> alerts) async {
    final result = await reasoningModel.generateCompletion(
      messages: [
        cactus.ChatMessage(
          role: 'system',
          content: 'You are a medical assistant. Answer based on the facts provided.',
        ),
        cactus.ChatMessage(
          role: 'user',
          content: '''Query: $query

Facts:
${facts.map((f) => '- $f').join('\n')}

Provide a clear, concise answer:''',
        ),
      ],
    );

    return result.response;
  }
}


// ---------------------------------------------
// Supporting Classes
// ---------------------------------------------
class ToolCall {
  final String name;
  final Map<String, dynamic> arguments;
  ToolCall({required this.name, required this.arguments});
}

class CdsAlert {
  final String title;
  final String severity;
  final String recommendation;
  CdsAlert({required this.title, required this.severity, required this.recommendation});
}

// Stubs for compilation
class FhirService {
  Future<Map<String, dynamic>> getPatientManifest(String id) async => {};
  Future<Map<String, dynamic>> getConditions(String id) async => {};
  Future<Map<String, dynamic>> getMedications(String id) async => {};
  Future<Map<String, dynamic>> getObservations(String id) async => {};
}

class CdsEngine {
  Future<List<CdsAlert>> checkAll(Map<String, dynamic> data) async => [];
}

class ToolRegistry {
  static List<cactus.CactusTool> tools = [];
}
