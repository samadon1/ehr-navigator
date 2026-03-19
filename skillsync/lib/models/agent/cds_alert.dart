/// Severity levels for clinical decision support alerts
enum CdsSeverity {
  low,
  moderate,
  high,
  critical,
}

/// Types of clinical decision support alerts
enum CdsAlertType {
  drugInteraction,
  allergyAlert,
  careGap,
  abnormalResult,
  dosageWarning,
  contraindication,
  other,
}

/// A clinical decision support alert
class CdsAlert {
  final String id;
  final CdsAlertType type;
  final CdsSeverity severity;
  final String title;
  final String description;
  final List<String> recommendations;
  final Map<String, dynamic>? context;
  final DateTime timestamp;
  final bool acknowledged;

  CdsAlert({
    String? id,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    this.recommendations = const [],
    this.context,
    DateTime? timestamp,
    this.acknowledged = false,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now();

  factory CdsAlert.fromJson(Map<String, dynamic> json) {
    return CdsAlert(
      id: json['id'] as String?,
      type: CdsAlertType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => CdsAlertType.other,
      ),
      severity: CdsSeverity.values.firstWhere(
        (s) => s.name == json['severity'],
        orElse: () => CdsSeverity.moderate,
      ),
      title: json['title'] as String,
      description: json['description'] as String,
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((r) => r as String)
              .toList() ??
          [],
      context: json['context'] as Map<String, dynamic>?,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
      acknowledged: json['acknowledged'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'severity': severity.name,
        'title': title,
        'description': description,
        'recommendations': recommendations,
        if (context != null) 'context': context,
        'timestamp': timestamp.toIso8601String(),
        'acknowledged': acknowledged,
      };

  CdsAlert copyWith({
    CdsAlertType? type,
    CdsSeverity? severity,
    String? title,
    String? description,
    List<String>? recommendations,
    Map<String, dynamic>? context,
    bool? acknowledged,
  }) {
    return CdsAlert(
      id: id,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      description: description ?? this.description,
      recommendations: recommendations ?? this.recommendations,
      context: context ?? this.context,
      timestamp: timestamp,
      acknowledged: acknowledged ?? this.acknowledged,
    );
  }

  /// Get severity display string
  String get severityDisplay {
    switch (severity) {
      case CdsSeverity.critical:
        return 'CRITICAL';
      case CdsSeverity.high:
        return 'High';
      case CdsSeverity.moderate:
        return 'Moderate';
      case CdsSeverity.low:
        return 'Low';
    }
  }

  /// Get type display string
  String get typeDisplay {
    switch (type) {
      case CdsAlertType.drugInteraction:
        return 'Drug Interaction';
      case CdsAlertType.allergyAlert:
        return 'Allergy Alert';
      case CdsAlertType.careGap:
        return 'Care Gap';
      case CdsAlertType.abnormalResult:
        return 'Abnormal Result';
      case CdsAlertType.dosageWarning:
        return 'Dosage Warning';
      case CdsAlertType.contraindication:
        return 'Contraindication';
      case CdsAlertType.other:
        return 'Alert';
    }
  }

  @override
  String toString() => 'CdsAlert(${severity.name}: $title)';
}
