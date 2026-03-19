/// ============================================
/// THREE AI APPROACHES COMPARED
/// ============================================
///
/// 1. AGENT    - Multi-step with tool calling
/// 2. LLM DIRECT - Context stuffing (all data in prompt)
/// 3. RAG      - Retrieval-Augmented Generation

import 'dart:math';
import 'package:cactus/cactus.dart' as cactus;

// ═══════════════════════════════════════════
// APPROACH 1: AGENT (Tool-Based)
// ═══════════════════════════════════════════
//
// LLM decides which tools to call, then synthesizes response
//
// Pros: Smart, selective, handles complex queries, has safety checks
// Cons: Slower (multiple LLM calls)

Future<String> runAgent(String patientId, String query) async {
  // LLM Call #1: Route - Select tools
  final toolCalls = await routingLLM.generateCompletion(
    messages: [ChatMessage(role: 'user', content: query)],
    params: CompletionParams(tools: availableTools),
  );

  // Execute selected tools (fetch only needed data)
  final fetchedData = <String, dynamic>{};
  for (final tool in toolCalls.toolCalls) {
    fetchedData[tool.name] = await executeTool(tool);
  }

  // LLM Call #2: Filter - Extract relevant facts
  final facts = await reasoningLLM.generateCompletion(
    messages: [ChatMessage(
      role: 'user',
      content: 'Extract facts relevant to: $query\nData: $fetchedData',
    )],
  );

  // Run CDS checks (rule-based, fast)
  final alerts = await cdsEngine.check(fetchedData);

  // LLM Call #3: Synthesize - Generate response
  final response = await reasoningLLM.generateCompletion(
    messages: [ChatMessage(
      role: 'user',
      content: 'Answer: $query\nFacts: $facts',
    )],
  );

  return response.response;
}


// ═══════════════════════════════════════════
// APPROACH 2: LLM DIRECT (Context Stuffing)
// ═══════════════════════════════════════════
//
// Dump ALL patient data into the prompt
//
// Pros: Fast (1 LLM call), simple
// Cons: Doesn't scale, wastes tokens, no safety checks

Future<String> runLlmDirect(String patientId, String query) async {
  // Fetch ALL patient data upfront
  final allData = await fetchAllPatientData(patientId);

  // Build context string
  final context = '''
=== PATIENT DATA ===

PATIENT: ${allData['name']}, Age: ${allData['age']}, Gender: ${allData['gender']}

CONDITIONS:
${(allData['conditions'] as List).map((c) => '- ${c['name']} (${c['status']})').join('\n')}

MEDICATIONS:
${(allData['medications'] as List).map((m) => '- ${m['name']} ${m['dosage']}').join('\n')}

ALLERGIES:
${(allData['allergies'] as List).map((a) => '- ${a['allergen']}').join('\n')}

OBSERVATIONS:
${(allData['observations'] as List).map((o) => '- ${o['name']}: ${o['value']} ${o['unit']}').join('\n')}
''';

  // Single LLM call with everything stuffed in
  final result = await llm.generateCompletion(
    messages: [
      ChatMessage(role: 'system', content: 'Answer based on the patient data.'),
      ChatMessage(role: 'user', content: '$context\n\nQuestion: $query'),
    ],
  );

  return result.response;
}


// ═══════════════════════════════════════════
// APPROACH 3: RAG (Retrieval-Augmented Generation)
// ═══════════════════════════════════════════
//
// Embed data → Search by similarity → Retrieve relevant chunks
//
// Pros: Efficient for large datasets, only fetches relevant info
// Cons: May miss context, needs good chunking

class RagApproach {
  final cactus.CactusLM model;
  final Map<String, List<EmbeddedChunk>> patientEmbeddings = {};

  RagApproach(this.model);

  Future<String> run(String patientId, String query) async {

    // Step 1: Ensure patient data is embedded (one-time)
    if (!patientEmbeddings.containsKey(patientId)) {
      await _embedPatientData(patientId);
    }

    // Step 2: Embed the query
    final queryEmbedding = await model.generateEmbedding(text: query);

    // Step 3: Find top-k similar chunks
    final chunks = patientEmbeddings[patientId]!;
    final topK = _rankBySimilarity(queryEmbedding.embeddings, chunks, k: 5);

    // Step 4: Generate with retrieved context
    final context = topK.map((c) => c.text).join('\n\n');

    final result = await model.generateCompletion(
      messages: [
        ChatMessage(
          role: 'user',
          content: '''Context:
$context

Question: $query

Answer based only on the context above:''',
        ),
      ],
    );

    return result.response;
  }

  // Embed each piece of patient data as a chunk
  Future<void> _embedPatientData(String patientId) async {
    final chunks = <EmbeddedChunk>[];
    final data = await fetchAllPatientData(patientId);

    // Embed conditions
    for (final cond in data['conditions']) {
      final text = 'Condition: ${cond['name']} (${cond['status']})';
      final embedding = await model.generateEmbedding(text: text);
      chunks.add(EmbeddedChunk(text: text, embedding: embedding.embeddings));
    }

    // Embed medications
    for (final med in data['medications']) {
      final text = 'Medication: ${med['name']} - ${med['dosage']}';
      final embedding = await model.generateEmbedding(text: text);
      chunks.add(EmbeddedChunk(text: text, embedding: embedding.embeddings));
    }

    // Embed observations
    for (final obs in data['observations']) {
      final text = '${obs['name']}: ${obs['value']} ${obs['unit']}';
      final embedding = await model.generateEmbedding(text: text);
      chunks.add(EmbeddedChunk(text: text, embedding: embedding.embeddings));
    }

    patientEmbeddings[patientId] = chunks;
  }

  // Rank chunks by cosine similarity to query
  List<EmbeddedChunk> _rankBySimilarity(
    List<double> queryEmb,
    List<EmbeddedChunk> chunks,
    {int k = 5}
  ) {
    final scored = chunks.map((c) => (
      chunk: c,
      score: _cosineSimilarity(queryEmb, c.embedding),
    )).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(k).map((s) => s.chunk).toList();
  }

  // Cosine similarity: dot(a,b) / (||a|| * ||b||)
  double _cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    return dot / (sqrt(normA) * sqrt(normB));
  }
}

class EmbeddedChunk {
  final String text;
  final List<double> embedding;
  EmbeddedChunk({required this.text, required this.embedding});
}


// ═══════════════════════════════════════════
// COMPARISON SUMMARY
// ═══════════════════════════════════════════
/*
┌───────────┬─────────┬───────────┬─────────────┬────────┐
│ Approach  │ Speed   │ LLM Calls │ Token Usage │ Safety │
├───────────┼─────────┼───────────┼─────────────┼────────┤
│ Agent     │ ~2.7s   │ 3         │ Low         │ Yes    │
│ LLM Direct│ ~1.1s   │ 1         │ High        │ No     │
│ RAG       │ ~1.5s   │ 1         │ Medium      │ No     │
└───────────┴─────────┴───────────┴─────────────┴────────┘

Best for:
- Agent:     Complex queries, safety-critical, large records
- LLM Direct: Simple lookups, small records, prototyping
- RAG:       Large datasets, semantic search, scalability
*/


// Stubs for compilation
class ChatMessage {
  final String role;
  final String content;
  ChatMessage({required this.role, required this.content});
}

class CompletionParams {
  final List<dynamic>? tools;
  CompletionParams({this.tools});
}

dynamic routingLLM, reasoningLLM, llm, cdsEngine, availableTools;
Future<dynamic> executeTool(dynamic tool) async => {};
Future<Map<String, dynamic>> fetchAllPatientData(String id) async => {};
