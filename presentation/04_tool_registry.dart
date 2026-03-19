/// ============================================
/// TOOL REGISTRY - Available Agent Tools
/// ============================================
///
/// Tools define what actions the agent can take
/// LLM selects tools based on the user's query

import 'package:cactus/cactus.dart';

class ToolRegistry {

  /// All available tools for the EHR Agent
  static final List<CactusTool> tools = [

    // ---------------------------------------------
    // Patient Demographics
    // ---------------------------------------------
    CactusTool(
      name: 'get_patient_info',
      description: 'Get patient demographics: name, age, gender, contact info',
      parameters: ToolParametersSchema(
        properties: {
          'patient_id': ToolParameter(
            type: 'string',
            description: 'Patient ID',
            required: true,
          ),
        },
      ),
    ),

    // ---------------------------------------------
    // Medical Conditions
    // ---------------------------------------------
    CactusTool(
      name: 'get_conditions',
      description: 'Get patient diagnoses and medical conditions',
      parameters: ToolParametersSchema(
        properties: {
          'patient_id': ToolParameter(type: 'string', required: true),
          'status': ToolParameter(
            type: 'string',
            description: 'Filter: active, resolved, or all',
          ),
        },
      ),
    ),

    // ---------------------------------------------
    // Medications
    // ---------------------------------------------
    CactusTool(
      name: 'get_medications',
      description: 'Get current and past medications with dosages',
      parameters: ToolParametersSchema(
        properties: {
          'patient_id': ToolParameter(type: 'string', required: true),
          'status': ToolParameter(
            type: 'string',
            description: 'Filter: active, stopped, or all',
          ),
        },
      ),
    ),

    // ---------------------------------------------
    // Lab Results & Vitals
    // ---------------------------------------------
    CactusTool(
      name: 'get_observations',
      description: 'Get lab results and vital signs',
      parameters: ToolParametersSchema(
        properties: {
          'patient_id': ToolParameter(type: 'string', required: true),
          'category': ToolParameter(
            type: 'string',
            description: 'Filter: vital-signs, laboratory, or all',
          ),
          'code': ToolParameter(
            type: 'string',
            description: 'LOINC code for specific test (e.g., HbA1c)',
          ),
        },
      ),
    ),

    // ---------------------------------------------
    // Allergies
    // ---------------------------------------------
    CactusTool(
      name: 'get_allergies',
      description: 'Get allergies and intolerances with severity',
      parameters: ToolParametersSchema(
        properties: {
          'patient_id': ToolParameter(type: 'string', required: true),
          'category': ToolParameter(
            type: 'string',
            description: 'Filter: medication, food, environment',
          ),
        },
      ),
    ),

    // ---------------------------------------------
    // Drug Interactions (CDS)
    // ---------------------------------------------
    CactusTool(
      name: 'check_drug_interactions',
      description: 'Check for dangerous drug-drug interactions',
      parameters: ToolParametersSchema(
        properties: {
          'patient_id': ToolParameter(type: 'string', required: true),
          'proposed_medication': ToolParameter(
            type: 'string',
            description: 'New medication to check against current meds',
          ),
        },
      ),
    ),
  ];

  /// Get tool by name
  static CactusTool? getTool(String name) {
    return tools.where((t) => t.name == name).firstOrNull;
  }

  /// Get summary for LLM prompt
  static String getSummary() {
    return tools.map((t) => '- ${t.name}: ${t.description}').join('\n');
  }
}


// ---------------------------------------------
// Example: How LLM Uses Tools
// ---------------------------------------------
/*
User: "What medications is the patient taking?"
       ↓
LLM selects: get_medications(patient_id: "123")
       ↓
Tool returns: {medications: [{name: "Metformin", dosage: "500mg"}]}
       ↓
LLM synthesizes: "The patient is taking Metformin 500mg."


User: "Are there any drug interactions?"
       ↓
LLM selects: [get_medications, check_drug_interactions]
       ↓
Tools return medication list + interaction alerts
       ↓
LLM synthesizes: "Warning: Warfarin + Aspirin interaction detected."
*/
