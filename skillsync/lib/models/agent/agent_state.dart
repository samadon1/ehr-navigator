import 'tool_call.dart';
import 'cds_alert.dart';

/// Phases of the agent workflow
enum AgentPhase {
  idle,
  discovery,
  routing,
  executing,
  filtering,
  cdsChecking,
  synthesizing,
  complete,
  error,
}

/// A step in the agent's reasoning process (for audit/display)
class AgentStep {
  final AgentPhase phase;
  final String description;
  final DateTime timestamp;
  final Duration? duration;
  final Map<String, dynamic>? data;

  AgentStep({
    required this.phase,
    required this.description,
    DateTime? timestamp,
    this.duration,
    this.data,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'phase': phase.name,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
        if (duration != null) 'durationMs': duration!.inMilliseconds,
        if (data != null) 'data': data,
      };

  /// Get a short display name for the phase
  String get phaseDisplay {
    switch (phase) {
      case AgentPhase.idle:
        return 'Idle';
      case AgentPhase.discovery:
        return 'Discovering';
      case AgentPhase.routing:
        return 'Planning';
      case AgentPhase.executing:
        return 'Fetching Data';
      case AgentPhase.filtering:
        return 'Analyzing';
      case AgentPhase.cdsChecking:
        return 'Checking Alerts';
      case AgentPhase.synthesizing:
        return 'Generating Response';
      case AgentPhase.complete:
        return 'Complete';
      case AgentPhase.error:
        return 'Error';
    }
  }
}

/// The complete state of the agent during a query
class AgentState {
  final String patientId;
  final String query;
  final AgentPhase phase;
  final Map<String, List<String>> availableResources;
  final List<String> relevantResourceTypes;
  final List<ToolCall> plannedToolCalls;
  final List<ToolResult> toolResults;
  final Map<String, dynamic> fetchedData;
  final List<String> collectedFacts;
  final List<CdsAlert> alerts;
  final String? response;
  final String? thinking; // Model's internal reasoning (collapsible in UI)
  final String? error;
  final List<AgentStep> steps;
  final DateTime startTime;
  final DateTime? endTime;

  AgentState({
    required this.patientId,
    required this.query,
    this.phase = AgentPhase.idle,
    this.availableResources = const {},
    this.relevantResourceTypes = const [],
    this.plannedToolCalls = const [],
    this.toolResults = const [],
    this.fetchedData = const {},
    this.collectedFacts = const [],
    this.alerts = const [],
    this.response,
    this.thinking,
    this.error,
    this.steps = const [],
    DateTime? startTime,
    this.endTime,
  }) : startTime = startTime ?? DateTime.now();

  /// Create a copy with updated fields
  AgentState copyWith({
    AgentPhase? phase,
    Map<String, List<String>>? availableResources,
    List<String>? relevantResourceTypes,
    List<ToolCall>? plannedToolCalls,
    List<ToolResult>? toolResults,
    Map<String, dynamic>? fetchedData,
    List<String>? collectedFacts,
    List<CdsAlert>? alerts,
    String? response,
    String? thinking,
    String? error,
    List<AgentStep>? steps,
    DateTime? endTime,
  }) {
    return AgentState(
      patientId: patientId,
      query: query,
      phase: phase ?? this.phase,
      availableResources: availableResources ?? this.availableResources,
      relevantResourceTypes: relevantResourceTypes ?? this.relevantResourceTypes,
      plannedToolCalls: plannedToolCalls ?? this.plannedToolCalls,
      toolResults: toolResults ?? this.toolResults,
      fetchedData: fetchedData ?? this.fetchedData,
      collectedFacts: collectedFacts ?? this.collectedFacts,
      alerts: alerts ?? this.alerts,
      response: response ?? this.response,
      thinking: thinking ?? this.thinking,
      error: error ?? this.error,
      steps: steps ?? this.steps,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  /// Add a step to the reasoning trace
  AgentState addStep(AgentStep step) {
    return copyWith(steps: [...steps, step]);
  }

  /// Add collected facts
  AgentState addFacts(List<String> newFacts) {
    return copyWith(collectedFacts: [...collectedFacts, ...newFacts]);
  }

  /// Add a tool result
  AgentState addToolResult(ToolResult result) {
    return copyWith(toolResults: [...toolResults, result]);
  }

  /// Add alerts
  AgentState addAlerts(List<CdsAlert> newAlerts) {
    return copyWith(alerts: [...alerts, ...newAlerts]);
  }

  /// Check if the agent is currently processing
  bool get isProcessing =>
      phase != AgentPhase.idle &&
      phase != AgentPhase.complete &&
      phase != AgentPhase.error;

  /// Check if the agent has completed
  bool get isComplete => phase == AgentPhase.complete;

  /// Check if the agent encountered an error
  bool get hasError => phase == AgentPhase.error || error != null;

  /// Get total execution time
  Duration? get executionTime {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }

  /// Get current phase description
  String get phaseDescription {
    switch (phase) {
      case AgentPhase.idle:
        return 'Ready';
      case AgentPhase.discovery:
        return 'Discovering available patient data...';
      case AgentPhase.routing:
        return 'Planning which data to retrieve...';
      case AgentPhase.executing:
        return 'Fetching patient records...';
      case AgentPhase.filtering:
        return 'Extracting relevant facts...';
      case AgentPhase.cdsChecking:
        return 'Running clinical checks...';
      case AgentPhase.synthesizing:
        return 'Generating response...';
      case AgentPhase.complete:
        return 'Complete';
      case AgentPhase.error:
        return 'Error occurred';
    }
  }

  /// Check if there are critical alerts
  bool get hasCriticalAlerts =>
      alerts.any((a) => a.severity == CdsSeverity.critical);

  /// Check if there are high priority alerts
  bool get hasHighPriorityAlerts =>
      alerts.any((a) =>
          a.severity == CdsSeverity.critical ||
          a.severity == CdsSeverity.high);

  Map<String, dynamic> toJson() => {
        'patientId': patientId,
        'query': query,
        'phase': phase.name,
        'availableResources': availableResources,
        'relevantResourceTypes': relevantResourceTypes,
        'plannedToolCalls': plannedToolCalls.map((t) => t.toJson()).toList(),
        'toolResults': toolResults.map((r) => r.toJson()).toList(),
        'fetchedData': fetchedData,
        'collectedFacts': collectedFacts,
        'alerts': alerts.map((a) => a.toJson()).toList(),
        if (response != null) 'response': response,
        if (thinking != null) 'thinking': thinking,
        if (error != null) 'error': error,
        'steps': steps.map((s) => s.toJson()).toList(),
        'startTime': startTime.toIso8601String(),
        if (endTime != null) 'endTime': endTime!.toIso8601String(),
      };
}
