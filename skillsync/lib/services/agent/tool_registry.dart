import 'package:cactus/cactus.dart';

/// Registry of tools available to the EHR Navigator agent
/// Tools are defined using CactusTool format from the official package
class ToolRegistry {
  /// All EHR Navigator tools using CactusTool format
  static final List<CactusTool> ehrTools = [
    CactusTool(
      name: 'get_patient_info',
      description:
          'Retrieve basic patient demographics including name, date of birth, gender, age, and contact information.',
      parameters: ToolParametersSchema(
        properties: {
          'patient_id': ToolParameter(
            type: 'string',
            description: 'The unique patient identifier',
            required: true,
          ),
        },
      ),
    ),
    CactusTool(
      name: 'get_conditions',
      description:
          'Retrieve patient diagnoses and medical conditions. Can filter by status (active, resolved) or category.',
      parameters: ToolParametersSchema(
        properties: {
          'patient_id': ToolParameter(
            type: 'string',
            description: 'The unique patient identifier',
            required: true,
          ),
          'status': ToolParameter(
            type: 'string',
            description: 'Filter by clinical status: active, resolved, or all. Default is all.',
            required: false,
          ),
          'category': ToolParameter(
            type: 'string',
            description: 'Filter by condition category',
            required: false,
          ),
        },
      ),
    ),
    CactusTool(
      name: 'get_medications',
      description:
          'Retrieve current and historical medications. Returns medication name, dosage, frequency, and status.',
      parameters: ToolParametersSchema(
        properties: {
          'patient_id': ToolParameter(
            type: 'string',
            description: 'The unique patient identifier',
            required: true,
          ),
          'status': ToolParameter(
            type: 'string',
            description: 'Filter by medication status: active, stopped, or all. Default is active.',
            required: false,
          ),
          'include_historical': ToolParameter(
            type: 'boolean',
            description: 'Include historical/stopped medications. Default is false.',
            required: false,
          ),
        },
      ),
    ),
    CactusTool(
      name: 'get_observations',
      description:
          'Retrieve lab results, vital signs, and other clinical observations.',
      parameters: ToolParametersSchema(
        properties: {
          'patient_id': ToolParameter(
            type: 'string',
            description: 'The unique patient identifier',
            required: true,
          ),
          'category': ToolParameter(
            type: 'string',
            description: 'Filter by observation category: vital-signs, laboratory, social-history, or all. Default is all.',
            required: false,
          ),
          'code': ToolParameter(
            type: 'string',
            description: 'LOINC code to filter by specific observation type',
            required: false,
          ),
          'date_from': ToolParameter(
            type: 'string',
            description: 'Start date filter (ISO 8601 format)',
            required: false,
          ),
          'date_to': ToolParameter(
            type: 'string',
            description: 'End date filter (ISO 8601 format)',
            required: false,
          ),
        },
      ),
    ),
    CactusTool(
      name: 'get_encounters',
      description:
          'Retrieve patient visit history including hospitalizations, outpatient visits, and emergency visits.',
      parameters: ToolParametersSchema(
        properties: {
          'patient_id': ToolParameter(
            type: 'string',
            description: 'The unique patient identifier',
            required: true,
          ),
          'class': ToolParameter(
            type: 'string',
            description: 'Filter by encounter class: inpatient, outpatient, emergency, or all. Default is all.',
            required: false,
          ),
          'limit': ToolParameter(
            type: 'integer',
            description: 'Maximum number of encounters to return. Default is 10.',
            required: false,
          ),
        },
      ),
    ),
    CactusTool(
      name: 'get_allergies',
      description:
          'Retrieve patient allergy and intolerance information including severity and reactions.',
      parameters: ToolParametersSchema(
        properties: {
          'patient_id': ToolParameter(
            type: 'string',
            description: 'The unique patient identifier',
            required: true,
          ),
          'category': ToolParameter(
            type: 'string',
            description: 'Filter by allergy category: medication, food, environment, or all. Default is all.',
            required: false,
          ),
        },
      ),
    ),
    CactusTool(
      name: 'check_drug_interactions',
      description:
          'Check for potential drug-drug interactions between patient current medications.',
      parameters: ToolParametersSchema(
        properties: {
          'patient_id': ToolParameter(
            type: 'string',
            description: 'The unique patient identifier',
            required: true,
          ),
          'proposed_medication': ToolParameter(
            type: 'string',
            description: 'Optional: medication name or RxNorm code to check against current medications',
            required: false,
          ),
        },
      ),
    ),
    // === TREND TOOLS ===
    CactusTool(
      name: 'get_vital_trends',
      description:
          'Get vital sign trends over time with statistics. Returns time-series data for blood pressure, heart rate, weight, temperature, BMI, respiratory rate, and oxygen saturation. Useful for monitoring patient health trends.',
      parameters: ToolParametersSchema(
        properties: {
          'patient_id': ToolParameter(
            type: 'string',
            description: 'The unique patient identifier',
            required: true,
          ),
          'vital_type': ToolParameter(
            type: 'string',
            description: 'Type of vital sign: blood_pressure, heart_rate, weight, height, temperature, bmi, respiratory_rate, oxygen_saturation. Leave empty for all vitals.',
            required: false,
          ),
          'limit_days': ToolParameter(
            type: 'integer',
            description: 'Limit data to last N days. Default is all available data.',
            required: false,
          ),
        },
      ),
    ),
    CactusTool(
      name: 'get_lab_trends',
      description:
          'Get laboratory result trends over time with statistics. Returns time-series data for glucose, HbA1c, cholesterol, LDL, HDL, triglycerides, creatinine, eGFR, and more. Flags abnormal values.',
      parameters: ToolParametersSchema(
        properties: {
          'patient_id': ToolParameter(
            type: 'string',
            description: 'The unique patient identifier',
            required: true,
          ),
          'lab_type': ToolParameter(
            type: 'string',
            description: 'Type of lab: glucose, hba1c, cholesterol, ldl, hdl, triglycerides, creatinine, egfr, potassium, sodium, hemoglobin, wbc, platelets, or a LOINC code. Leave empty for all labs.',
            required: false,
          ),
          'limit_days': ToolParameter(
            type: 'integer',
            description: 'Limit data to last N days. Default is all available data.',
            required: false,
          ),
        },
      ),
    ),
    // === CLINICAL DECISION SUPPORT TOOLS ===
    CactusTool(
      name: 'get_critical_results',
      description:
          'Get abnormal/critical lab results that need clinical attention. Groups results by urgency: last 7 days, last 30 days, and older. Essential for prioritizing follow-up care.',
      parameters: ToolParametersSchema(
        properties: {
          'patient_id': ToolParameter(
            type: 'string',
            description: 'The unique patient identifier',
            required: true,
          ),
        },
      ),
    ),
    CactusTool(
      name: 'check_overdue_screenings',
      description:
          'Check for overdue health screenings and care gaps. Evaluates blood pressure, lipid panel, HbA1c (for diabetics), kidney function, colorectal cancer screening based on age, gender, and conditions.',
      parameters: ToolParametersSchema(
        properties: {
          'patient_id': ToolParameter(
            type: 'string',
            description: 'The unique patient identifier',
            required: true,
          ),
        },
      ),
    ),
    CactusTool(
      name: 'get_immunizations',
      description:
          'Get patient vaccination history including all immunizations, grouped by vaccine type with dates.',
      parameters: ToolParametersSchema(
        properties: {
          'patient_id': ToolParameter(
            type: 'string',
            description: 'The unique patient identifier',
            required: true,
          ),
        },
      ),
    ),
    CactusTool(
      name: 'get_recent_visits',
      description:
          'Get recent patient visits with context for care handoffs. Includes visit type, reason, and key findings from each encounter. Useful for shift handoffs and care coordination.',
      parameters: ToolParametersSchema(
        properties: {
          'patient_id': ToolParameter(
            type: 'string',
            description: 'The unique patient identifier',
            required: true,
          ),
          'limit': ToolParameter(
            type: 'integer',
            description: 'Maximum number of recent visits to return. Default is 5.',
            required: false,
          ),
        },
      ),
    ),
  ];

  /// Get tool definitions for the agent (CactusTool format)
  static List<CactusTool> getTools() => ehrTools;

  /// Get tool definitions as raw maps (for native FFI API)
  static List<Map<String, dynamic>> getToolsAsJson() {
    return ehrTools.map((tool) => {
      'type': 'function',
      'function': {
        'name': tool.name,
        'description': tool.description,
        'parameters': {
          'type': 'object',
          'properties': tool.parameters.properties.map((key, param) => MapEntry(key, {
            'type': param.type,
            'description': param.description,
          })),
          'required': tool.parameters.properties.entries
              .where((e) => e.value.required == true)
              .map((e) => e.key)
              .toList(),
        },
      },
    }).toList();
  }

  /// Get a specific tool by name
  static CactusTool? getTool(String name) {
    try {
      return ehrTools.firstWhere((t) => t.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Get tool names
  static List<String> getToolNames() {
    return ehrTools.map((t) => t.name).toList();
  }

  /// Get tool description by name
  static String? getToolDescription(String name) {
    final tool = getTool(name);
    return tool?.description;
  }

  /// Generate a summary of available tools for the agent
  static String getToolsSummary() {
    final buffer = StringBuffer();
    buffer.writeln('Available tools:');
    for (final tool in ehrTools) {
      buffer.writeln('- ${tool.name}: ${tool.description}');
    }
    return buffer.toString();
  }
}
