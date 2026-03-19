# EHR Navigator: On-Device AI Agent Architecture

A comprehensive guide to FHIR, Cactus SDK, and three AI approaches (Agent, LLM Direct, RAG).

---

## Table of Contents

1. [FHIR (Healthcare Data Standard)](#1-fhir-healthcare-data-standard)
2. [Cactus SDK (On-Device LLM)](#2-cactus-sdk-on-device-llm)
3. [Three AI Approaches Compared](#3-three-ai-approaches-compared)
4. [The Full Agent Pipeline](#4-the-full-agent-pipeline)
5. [Clinical Decision Support (CDS)](#5-clinical-decision-support-cds)
6. [Key Code Snippets](#6-key-code-snippets)
7. [Performance & Caching](#7-performance--caching)

---

## 1. FHIR (Healthcare Data Standard)

### What is FHIR?

**FHIR** (Fast Healthcare Interoperability Resources) is a standard for exchanging healthcare information electronically.

**Key Concept:** Everything is a "Resource" (Patient, Medication, Condition, Observation, etc.)

### FHIR Resource Base Class

```dart
abstract class FhirResource {
  final String resourceType;  // "Patient", "Medication", etc.
  final String id;
  final FhirMeta? meta;

  Map<String, dynamic> toJson();
  String get displaySummary;
}
```

### Patient Resource Example

```dart
class Patient extends FhirResource {
  final String? gender;
  final DateTime? birthDate;
  final List<HumanName> name;
  final List<Address> address;
  final List<ContactPoint> telecom;

  String get displayName => name.first.display;
  int? get age => /* calculated from birthDate */;
}
```

### Sample FHIR JSON

```json
{
  "resourceType": "Patient",
  "id": "12345",
  "name": [
    {
      "given": ["John"],
      "family": "Smith"
    }
  ],
  "gender": "male",
  "birthDate": "1980-05-15",
  "address": [
    {
      "city": "Boston",
      "state": "MA"
    }
  ]
}
```

### Common FHIR Resources

| Resource | Description |
|----------|-------------|
| `Patient` | Demographics (name, DOB, gender, contact) |
| `Condition` | Diagnoses and problems |
| `MedicationRequest` | Prescriptions |
| `Observation` | Lab results, vital signs |
| `AllergyIntolerance` | Allergies and reactions |
| `Encounter` | Visits and hospitalizations |

---

## 2. Cactus SDK (On-Device LLM)

### What is Cactus?

**Cactus** is a Flutter/Dart SDK for running LLMs locally on mobile and desktop devices.

**Key Feature:** All data stays on-device - no cloud, complete privacy.

### Basic Usage

```dart
import 'package:cactus/cactus.dart' as cactus;

// Initialize model
final model = cactus.CactusLM();

// Download model (one-time)
await model.downloadModel(
  model: 'qwen3-0.6',
  downloadProcessCallback: (progress, status, isError) {
    print('Download: $progress% - $status');
  },
);

// Initialize for inference
await model.initializeModel(
  params: cactus.CactusInitParams(model: 'qwen3-0.6'),
);
```

### Generate Completion

```dart
final result = await model.generateCompletion(
  messages: [
    cactus.ChatMessage(
      role: 'system',
      content: 'You are a medical assistant.',
    ),
    cactus.ChatMessage(
      role: 'user',
      content: 'What medications is the patient taking?',
    ),
  ],
  params: cactus.CactusCompletionParams(
    maxTokens: 256,
    temperature: 0.5,
  ),
);

print(result.response);
```

### Streaming Completion

```dart
final streamedResult = await model.generateCompletionStream(
  messages: messages,
  params: cactus.CactusCompletionParams(maxTokens: 512),
);

// Yield tokens as they're generated
await for (final token in streamedResult.stream) {
  print(token);  // Real-time output
}
```

### Generate Embeddings (for RAG)

```dart
final embedding = await model.generateEmbedding(
  text: 'Diabetes mellitus type 2',
);

// Returns: List<double> of 384-1024 dimensions
print('Embedding dimensions: ${embedding.embeddings.length}');
```

### Tool Calling

```dart
final result = await model.generateCompletion(
  messages: messages,
  params: cactus.CactusCompletionParams(
    tools: [
      CactusTool(
        name: 'get_medications',
        description: 'Retrieve patient medications',
        parameters: ToolParametersSchema(
          properties: {
            'patient_id': ToolParameter(type: 'string', required: true),
          },
        ),
      ),
    ],
  ),
);

// Access tool calls
for (final toolCall in result.toolCalls) {
  print('Tool: ${toolCall.name}, Args: ${toolCall.arguments}');
}
```

---

## 3. Three AI Approaches Compared

### Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    USER QUERY                            │
│              "What medications? Any interactions?"       │
└─────────────────────────────────────────────────────────┘
                           │
         ┌─────────────────┼─────────────────┐
         ▼                 ▼                 ▼
    ┌─────────┐      ┌──────────┐      ┌─────────┐
    │  AGENT  │      │ LLM DIRECT│      │   RAG   │
    └────┬────┘      └────┬─────┘      └────┬────┘
         │                │                 │
    ┌────▼────┐      ┌────▼─────┐      ┌────▼────┐
    │ Routing │      │ Context  │      │ Embed   │
    │ (LLM)   │      │ Stuffing │      │ Query   │
    └────┬────┘      └────┬─────┘      └────┬────┘
         │                │                 │
    ┌────▼────┐           │           ┌────▼────┐
    │ Tools   │           │           │ Vector  │
    │ Execute │           │           │ Search  │
    └────┬────┘           │           └────┬────┘
         │                │                 │
    ┌────▼────┐      ┌────▼─────┐      ┌────▼────┐
    │ Filter  │      │ Generate │      │ Generate│
    │ + CDS   │      │ Response │      │ Response│
    └────┬────┘      └──────────┘      └─────────┘
         │
    ┌────▼────┐
    │Synthesize│
    └──────────┘

    ~3 LLM calls        1 LLM call      1 LLM call
    + Safety Checks     No safety       No safety
```

---

### A) Agent (Tool-Based)

Multi-step reasoning with intelligent tool selection.

**Pipeline:**
```
User Query → Discovery → Routing → Execute Tools → Filter → CDS → Synthesize
```

**Tool Definition:**
```dart
CactusTool(
  name: 'get_medications',
  description: 'Retrieve current and historical medications',
  parameters: ToolParametersSchema(
    properties: {
      'patient_id': ToolParameter(type: 'string', required: true),
      'status': ToolParameter(type: 'string', description: 'active/stopped'),
    },
  ),
)
```

**How it works:**
- LLM analyzes query and selects which tools to call
- `"What medications?"` → calls `get_medications`
- `"Any allergies?"` → calls `get_allergies`
- `"Check interactions"` → calls `get_medications` + `check_drug_interactions`

| Pros | Cons |
|------|------|
| Smart, selective data retrieval | Slower (multiple LLM calls) |
| Handles complex queries | More complex implementation |
| CDS safety checks included | |
| Scales to large records | |

---

### B) LLM Direct (Context Stuffing)

Dump ALL patient data into the prompt.

```dart
Future<String> _runLlmDirect(String patientId, String query) async {
  // Fetch ALL data upfront
  final patientContext = await _buildPatientContext(patientId);

  final messages = [
    cactus.ChatMessage(
      role: 'system',
      content: 'Answer based on the patient data provided.',
    ),
    cactus.ChatMessage(
      role: 'user',
      content: '''$patientContext

Question: $query

Answer:''',
    ),
  ];

  return await model.generateCompletion(messages: messages);
}
```

**Context looks like:**
```
=== PATIENT DATA ===

PATIENT: John Smith, Age: 45, Gender: male

CONDITIONS:
- Diabetes mellitus type 2 (active)
- Hypertension (active)

MEDICATIONS:
- Metformin 500mg twice daily
- Lisinopril 10mg once daily

ALLERGIES:
- Penicillin (HIGH RISK)

OBSERVATIONS:
- HbA1c: 7.2 %
- Blood Pressure: 128/82 mmHg
```

| Pros | Cons |
|------|------|
| Fast (1 LLM call) | Doesn't scale to large records |
| Simple implementation | Wastes tokens on irrelevant data |
| | No safety checks |

---

### C) RAG (Retrieval-Augmented Generation)

Embed data → Search by similarity → Retrieve relevant chunks.

**Step 1: Embed patient data (one-time per patient)**
```dart
class _EmbeddedChunk {
  final String text;           // "Medication: Metformin 500mg"
  final List<double> embedding; // [0.12, -0.34, 0.56, ...]
}

// Embed each piece of data
for (final med in medications) {
  final text = 'Medication: ${med['name']} - ${med['dosage']}';
  final embedding = await model.generateEmbedding(text: text);
  chunks.add(_EmbeddedChunk(text: text, embedding: embedding.embeddings));
}
```

**Step 2: Embed the query**
```dart
final queryEmbedding = await model.generateEmbedding(text: query);
```

**Step 3: Find similar chunks (cosine similarity)**
```dart
double cosineSimilarity(List<double> a, List<double> b) {
  double dotProduct = 0, normA = 0, normB = 0;
  for (int i = 0; i < a.length; i++) {
    dotProduct += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  return dotProduct / (sqrt(normA) * sqrt(normB));
}

// Rank and get top-k chunks
final rankedChunks = chunks
    .map((c) => (chunk: c, score: cosineSimilarity(queryEmbedding, c.embedding)))
    .sorted((a, b) => b.score.compareTo(a.score))
    .take(5);
```

**Step 4: Generate with retrieved context**
```dart
final context = rankedChunks.map((c) => c.chunk.text).join('\n');

final response = await model.generateCompletion(
  messages: [
    cactus.ChatMessage(
      role: 'user',
      content: '''Context:
$context

Question: $query

Answer based only on the context above:''',
    ),
  ],
);
```

| Pros | Cons |
|------|------|
| Efficient for large datasets | May miss context |
| Only fetches relevant info | Needs good chunking strategy |
| Scales well | No safety checks |

---

### Comparison Summary

| Approach | Speed | LLM Calls | Token Usage | Safety | Best For |
|----------|-------|-----------|-------------|--------|----------|
| **Agent** | ~2.7s | 3 | Low (selective) | Yes (CDS) | Complex queries, safety-critical |
| **LLM Direct** | ~1.1s | 1 | High (all data) | No | Simple lookups, small records |
| **RAG** | ~1.5s | 1 | Medium (top-k) | No | Large datasets, search |

---

## 4. The Full Agent Pipeline

### State Machine (6 Phases)

```dart
enum AgentPhase {
  idle,         // Ready to receive query
  discovery,    // Find what data exists for patient
  routing,      // LLM decides which tools to call
  executing,    // Fetch FHIR data
  filtering,    // LLM extracts relevant facts
  cdsChecking,  // Rule-based safety checks
  synthesizing, // LLM generates response
  complete,     // Done
  error,        // Something went wrong
}
```

### Visual Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     USER QUERY                                   │
│            "Is the patient's diabetes controlled?"               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 1: DISCOVERY                                    ~50ms    │
│  ─────────────────────────────────────────────────────────────  │
│  • Query FHIR store for patient manifest                        │
│  • Returns: Available resource types (Conditions, Medications,  │
│             Observations, Allergies, Encounters...)             │
│  • CACHED after first query per patient                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 2: ROUTING (LLM Call #1)                       ~800ms    │
│  ─────────────────────────────────────────────────────────────  │
│  • LLM analyzes query + available resources                     │
│  • Outputs: List of tool calls to make                          │
│  • Example: "diabetes controlled?" →                            │
│      [get_conditions, get_observations, get_medications]        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 3: EXECUTING                                   ~100ms    │
│  ─────────────────────────────────────────────────────────────  │
│  • Call each tool to fetch FHIR data                            │
│  • Results CACHED per patient session                           │
│  • Returns: Raw FHIR resources                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 4: FILTERING (LLM Call #2)                     ~800ms    │
│  ─────────────────────────────────────────────────────────────  │
│  • LLM extracts ONLY relevant facts from fetched data           │
│  • Reduces noise, focuses on what matters for the query         │
│  • Output: List of concise facts                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 5: CDS CHECKING                                 ~10ms    │
│  ─────────────────────────────────────────────────────────────  │
│  • Rule-based clinical decision support                         │
│  • Check drug interactions, allergies                           │
│  • Output: List of safety alerts                                │
│  • CACHED per patient (only runs once per session)              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 6: SYNTHESIZING (LLM Call #3)                 ~1000ms    │
│  ─────────────────────────────────────────────────────────────  │
│  • LLM generates natural language response                      │
│  • Uses filtered facts + alerts                                 │
│  • STREAMING: Tokens yielded as generated                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     FINAL RESPONSE                               │
│  "The patient's diabetes appears partially controlled.          │
│   HbA1c is 7.2% (target <7%). Currently on Metformin 500mg."    │
│                                                                  │
│  ⚠️ ALERT: Drug interaction detected (shown in banner)          │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. Clinical Decision Support (CDS)

### What is CDS?

Rule-based safety checks that run alongside AI to catch dangerous situations.

### Drug Interaction Example

```dart
DrugInteraction(
  drug1: 'warfarin',
  drug2: 'aspirin',
  severity: InteractionSeverity.severe,
  description: 'Increased risk of serious bleeding',
  mechanism: 'Both drugs have anticoagulant/antiplatelet effects',
  recommendation: 'Monitor closely for signs of bleeding.',
)
```

### How It Works

```dart
// Check all medication pairs
for (var i = 0; i < medications.length; i++) {
  for (var j = i + 1; j < medications.length; j++) {
    final interaction = _findInteraction(medications[i], medications[j]);
    if (interaction != null) {
      alerts.add(createAlert(interaction));
    }
  }
}
```

### Common Interactions Checked

| Drug 1 | Drug 2 | Severity | Risk |
|--------|--------|----------|------|
| Warfarin | Aspirin | Severe | Bleeding |
| Warfarin | Ibuprofen | Severe | GI bleeding |
| Metformin | Contrast dye | Severe | Lactic acidosis |
| Lisinopril | Potassium | Moderate | Hyperkalemia |
| Oxycodone | Benzodiazepine | Severe | Respiratory depression |
| Sertraline | Tramadol | Severe | Serotonin syndrome |

---

## 6. Key Code Snippets

### The Main Agent Loop (Async Generator)

```dart
/// Process a user query - yields state updates as stream
Stream<AgentState> processQuery(String patientId, String query) async* {
  var state = AgentState(patientId: patientId, query: query);

  // Phase 1: Discovery
  state = state.copyWith(phase: AgentPhase.discovery);
  yield state;

  final manifest = await _fhirService.getPatientManifest(patientId);
  final availableResources = manifest['availableResources'];

  // Phase 2: Routing (LLM selects tools)
  state = state.copyWith(phase: AgentPhase.routing);
  yield state;

  final toolCalls = await _planTools(query, availableResources, patientId);

  // Phase 3: Execute tools
  state = state.copyWith(phase: AgentPhase.executing);
  yield state;

  for (final toolCall in toolCalls) {
    final result = await _toolExecutor.execute(toolCall);
    state = state.addToolResult(result);
    yield state;  // UI updates after each tool
  }

  // Phase 4: Filter (LLM extracts facts)
  state = state.copyWith(phase: AgentPhase.filtering);
  yield state;

  final facts = await _extractFacts(query, fetchedData);

  // Phase 5: CDS Check
  state = state.copyWith(phase: AgentPhase.cdsChecking);
  yield state;

  final alerts = await _toolExecutor.runCdsChecks(patientId);

  // Phase 6: Synthesize (LLM generates response with streaming)
  state = state.copyWith(phase: AgentPhase.synthesizing);
  yield state;

  await for (final token in _synthesizeWithModelStreaming(query, facts, alerts)) {
    state = state.copyWith(response: state.response + token);
    yield state;  // Real-time token streaming to UI
  }

  state = state.copyWith(phase: AgentPhase.complete);
  yield state;
}
```

### Tool Routing with LLM

```dart
Future<List<ToolCall>> _planToolsWithModel(String query, ...) async {
  final systemPrompt = '''You are an EHR navigation assistant.
Select which tools to call based on the user's question.

Available tools:
- get_patient_info: Basic demographics
- get_conditions: Diagnoses and medical conditions
- get_medications: Current and historical medications
- get_observations: Lab results, vital signs
- get_allergies: Allergies and intolerances
- get_encounters: Visit history
- check_drug_interactions: Safety check

Always call a tool. If unsure, call get_patient_info.''';

  final result = await _routingLM!.generateCompletion(
    messages: [
      ChatMessage(role: 'system', content: systemPrompt),
      ChatMessage(role: 'user', content: query),
    ],
    params: CactusCompletionParams(
      maxTokens: 256,
      temperature: 0.0,  // Deterministic
      tools: ToolRegistry.getTools(),  // Tool definitions
    ),
  );

  // LLM returns structured tool calls
  return result.toolCalls.map((tc) => ToolCall(
    name: tc.name,
    arguments: {...tc.arguments, 'patient_id': patientId},
  )).toList();
}
```

### Tool Executor

```dart
class ToolExecutor {
  Future<Map<String, dynamic>> _executeToolByName(
    String toolName,
    Map<String, dynamic> arguments,
  ) async {
    final patientId = arguments['patient_id'] as String;

    switch (toolName) {
      case 'get_patient_info':
        return _fhirService.getPatientInfo(patientId);

      case 'get_conditions':
        return _fhirService.getConditions(patientId,
          status: arguments['status'],
        );

      case 'get_medications':
        return _fhirService.getMedications(patientId,
          status: arguments['status'],
        );

      case 'get_observations':
        return _fhirService.getObservations(patientId,
          category: arguments['category'],
        );

      case 'check_drug_interactions':
        return _checkDrugInteractions(patientId);

      default:
        throw UnimplementedError('Unknown tool: $toolName');
    }
  }
}
```

### Fact Extraction with LLM

```dart
Future<List<String>> _extractFactsWithModel(String query, Map<String, dynamic> data) async {
  final facts = <String>[];

  for (final entry in data.entries) {
    final prompt = '''Extract relevant facts to answer: "$query"

Data source: ${entry.key}
Data: ${jsonEncode(entry.value)}

List only facts relevant to the question, one per line.''';

    final result = await _reasoningLM!.generateCompletion(
      messages: [
        ChatMessage(role: 'system', content: 'Extract key medical facts concisely.'),
        ChatMessage(role: 'user', content: prompt),
      ],
      params: CactusCompletionParams(maxTokens: 256, temperature: 0.3),
    );

    facts.addAll(result.response.split('\n').where((f) => f.isNotEmpty));
  }

  return facts;
}
```

### Streaming Response Synthesis

```dart
Stream<String> _synthesizeWithModelStreaming(
  String query,
  List<String> facts,
  List<CdsAlert> alerts,
) async* {
  final prompt = '''Answer this question: "$query"

COLLECTED FACTS:
${facts.map((f) => '- $f').join('\n')}

Provide a clear, concise answer based only on the facts above.''';

  final streamedResult = await _reasoningLM!.generateCompletionStream(
    messages: [
      ChatMessage(role: 'system', content: 'You are a medical assistant.'),
      ChatMessage(role: 'user', content: prompt),
    ],
    params: CactusCompletionParams(maxTokens: 512, temperature: 0.5),
  );

  // Yield tokens as they arrive (real-time UI update)
  await for (final token in streamedResult.stream) {
    yield token;
  }
}
```

### Agent State (Tracks Everything)

```dart
class AgentState {
  final String patientId;
  final String query;
  final AgentPhase phase;

  // What we discovered
  final Map<String, List<String>> availableResources;

  // What we planned
  final List<ToolCall> plannedToolCalls;

  // What we fetched
  final Map<String, dynamic> fetchedData;
  final List<ToolResult> toolResults;

  // What we extracted
  final List<String> collectedFacts;

  // Safety alerts
  final List<CdsAlert> alerts;

  // Final output
  final String? response;
  final String? thinking;  // Model's internal reasoning

  // Audit trail
  final List<AgentStep> steps;
  final DateTime startTime;
  final DateTime? endTime;

  Duration? get executionTime => endTime?.difference(startTime);
  bool get hasCriticalAlerts => alerts.any((a) => a.severity == CdsSeverity.critical);
}
```

---

## 7. Performance & Caching

### Caching Strategy

```dart
// Per-patient caches (cleared on patient switch)
final Map<String, Map<String, dynamic>> _manifestCache = {};      // Discovery
final Map<String, Map<String, dynamic>> _dataCache = {};          // Tool results
final Map<String, List<CdsAlert>> _alertsCache = {};              // CDS alerts
final Set<String> _cdsCheckedPatients = {};                       // CDS run flag
```

### Performance Impact

| Query | First Time | Subsequent |
|-------|------------|------------|
| Agent | ~2.7s | ~1.8s |
| LLM Direct | ~1.1s | ~1.0s |
| RAG | ~2.0s (embed) | ~1.5s |

### What Gets Cached

- **Patient Manifest**: Available resources (cached indefinitely per session)
- **Tool Results**: FHIR data fetched (cached per patient)
- **CDS Alerts**: Only runs once per patient per session
- **RAG Embeddings**: Patient data embeddings (cached per patient)

---

## Key Takeaways

| Feature | Implementation |
|---------|----------------|
| **Async Generator** | `Stream<AgentState>` yields updates for real-time UI |
| **Tool Calling** | LLM outputs structured `ToolCall` objects |
| **Streaming** | `generateCompletionStream()` for token-by-token output |
| **Caching** | Manifest, data, and CDS results cached per patient |
| **Fallbacks** | Keyword routing if LLM fails, simple synthesis if needed |
| **Safety** | CDS runs independently, alerts shown in persistent UI banner |
| **Privacy** | All processing on-device, no data leaves the device |

---

## File Structure

```
skillsync/lib/
├── models/
│   ├── fhir/
│   │   ├── fhir_resource.dart       # Base class
│   │   ├── patient.dart
│   │   ├── condition.dart
│   │   ├── medication.dart
│   │   └── observation.dart
│   └── agent/
│       ├── agent_state.dart         # State machine
│       ├── tool_call.dart
│       └── cds_alert.dart
├── services/
│   ├── ehr/
│   │   ├── fhir_store.dart          # Local JSON storage
│   │   └── fhir_query_service.dart
│   ├── agent/
│   │   ├── ehr_agent_service.dart   # Main agent loop
│   │   ├── tool_registry.dart       # Tool definitions
│   │   ├── tool_executor.dart       # Tool execution
│   │   └── comparison_service.dart  # 3-way comparison
│   └── cds/
│       ├── cds_engine.dart
│       └── drug_interaction.dart
└── screens/
    └── ehr/
        ├── agent_chat_screen.dart   # Main chat UI
        └── comparison_screen.dart   # Side-by-side comparison
```

---

*Generated from EHR Navigator codebase - On-Device AI for Healthcare*
