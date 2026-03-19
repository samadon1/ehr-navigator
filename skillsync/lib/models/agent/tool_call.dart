/// Represents a tool call made by the agent
class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  final DateTime timestamp;

  ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    return ToolCall(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] as String,
      arguments: json['arguments'] as Map<String, dynamic>? ?? {},
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'arguments': arguments,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  String toString() => 'ToolCall($name, args: $arguments)';
}

/// Result of executing a tool
class ToolResult {
  final String toolCallId;
  final String toolName;
  final Map<String, dynamic> result;
  final bool success;
  final String? error;
  final Duration executionTime;

  ToolResult({
    required this.toolCallId,
    required this.toolName,
    required this.result,
    this.success = true,
    this.error,
    required this.executionTime,
  });

  Map<String, dynamic> toJson() => {
        'toolCallId': toolCallId,
        'toolName': toolName,
        'result': result,
        'success': success,
        if (error != null) 'error': error,
        'executionTimeMs': executionTime.inMilliseconds,
      };
}
