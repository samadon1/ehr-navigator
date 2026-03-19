import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cactus/cactus.dart' as cactus;
import '../ehr/fhir_query_service.dart';
import 'ehr_agent_service.dart';

/// Result from a single approach
class ApproachResult {
  final String approach; // 'agent', 'llm', 'rag'
  final String response;
  final Duration duration;
  final bool isComplete;
  final String? error;
  final List<String>? retrievedChunks; // For RAG

  ApproachResult({
    required this.approach,
    required this.response,
    required this.duration,
    this.isComplete = false,
    this.error,
    this.retrievedChunks,
  });

  ApproachResult copyWith({
    String? response,
    Duration? duration,
    bool? isComplete,
    String? error,
  }) {
    return ApproachResult(
      approach: approach,
      response: response ?? this.response,
      duration: duration ?? this.duration,
      isComplete: isComplete ?? this.isComplete,
      error: error ?? this.error,
      retrievedChunks: retrievedChunks,
    );
  }
}

/// State for comparison mode
class ComparisonState {
  final ApproachResult agent;
  final ApproachResult llm;
  final ApproachResult rag;
  final bool isRunning;

  ComparisonState({
    required this.agent,
    required this.llm,
    required this.rag,
    this.isRunning = false,
  });

  factory ComparisonState.initial() {
    return ComparisonState(
      agent: ApproachResult(approach: 'agent', response: '', duration: Duration.zero),
      llm: ApproachResult(approach: 'llm', response: '', duration: Duration.zero),
      rag: ApproachResult(approach: 'rag', response: '', duration: Duration.zero),
    );
  }

  ComparisonState copyWith({
    ApproachResult? agent,
    ApproachResult? llm,
    ApproachResult? rag,
    bool? isRunning,
  }) {
    return ComparisonState(
      agent: agent ?? this.agent,
      llm: llm ?? this.llm,
      rag: rag ?? this.rag,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}

/// Service that runs all 3 approaches in parallel for comparison
class ComparisonService {
  final FhirQueryService _fhirService;
  final EhrAgentService _agentService;

  // Separate model instances for parallel execution
  cactus.CactusLM? _llmModel;
  cactus.CactusLM? _ragModel;

  // RAG: Embedded patient data chunks
  final Map<String, List<_EmbeddedChunk>> _patientEmbeddings = {};

  bool _initialized = false;
  String _modelName = 'qwen3-0.6';

  ComparisonService({
    required FhirQueryService fhirService,
    required EhrAgentService agentService,
  })  : _fhirService = fhirService,
        _agentService = agentService;

  bool get isInitialized => _initialized;

  /// Initialize the comparison service with 2 additional model instances
  /// (Agent service already has its own)
  Future<void> initialize({
    Function(double progress, String status)? onProgress,
  }) async {
    if (_initialized) return;

    try {
      // Initialize FHIR service first (needed for RAG)
      onProgress?.call(0.05, 'Initializing FHIR service...');
      await _fhirService.initialize();

      // Enable NPU
      cactus.CactusConfig.setProKey('cactus_live_2394695b111a3a4b9e72ccb46b2bc184');

      onProgress?.call(0.1, 'Loading LLM model...');

      // Initialize LLM Direct model
      _llmModel = cactus.CactusLM();
      await _llmModel!.downloadModel(
        model: _modelName,
        downloadProcessCallback: (progress, status, isError) {
          if (!isError) onProgress?.call(0.1 + (progress ?? 0) * 0.3, status);
        },
      );
      await _llmModel!.initializeModel(
        params: cactus.CactusInitParams(model: _modelName),
      );
      debugPrint('LLM Direct model initialized');

      onProgress?.call(0.5, 'Loading RAG model...');

      // Initialize RAG model
      _ragModel = cactus.CactusLM();
      await _ragModel!.downloadModel(
        model: _modelName,
        downloadProcessCallback: (progress, status, isError) {
          if (!isError) onProgress?.call(0.5 + (progress ?? 0) * 0.4, status);
        },
      );
      await _ragModel!.initializeModel(
        params: cactus.CactusInitParams(model: _modelName),
      );
      debugPrint('RAG model initialized');

      onProgress?.call(1.0, 'Ready');
      _initialized = true;
    } catch (e) {
      debugPrint('Failed to initialize comparison service: $e');
      rethrow;
    }
  }

  /// Run all 3 approaches in parallel
  Stream<ComparisonState> compare(String patientId, String query) async* {
    var state = ComparisonState.initial().copyWith(isRunning: true);
    yield state;

    // Start all 3 approaches in parallel
    final agentFuture = _runAgent(patientId, query);
    final llmFuture = _runLlmDirect(patientId, query);
    final ragFuture = _runRag(patientId, query);

    // Stream results as they complete
    final startTime = DateTime.now();

    // Use a completer map to track completion
    final results = <String, ApproachResult>{};
    var completed = 0;

    // Create streams for each
    agentFuture.then((result) {
      results['agent'] = result;
      completed++;
    });
    llmFuture.then((result) {
      results['llm'] = result;
      completed++;
    });
    ragFuture.then((result) {
      results['rag'] = result;
      completed++;
    });

    // Poll for results
    while (completed < 3) {
      await Future.delayed(const Duration(milliseconds: 100));

      // Update state with any new results
      if (results.containsKey('agent') && !state.agent.isComplete) {
        state = state.copyWith(agent: results['agent']);
        yield state;
      }
      if (results.containsKey('llm') && !state.llm.isComplete) {
        state = state.copyWith(llm: results['llm']);
        yield state;
      }
      if (results.containsKey('rag') && !state.rag.isComplete) {
        state = state.copyWith(rag: results['rag']);
        yield state;
      }
    }

    // Final state
    state = state.copyWith(
      agent: results['agent'],
      llm: results['llm'],
      rag: results['rag'],
      isRunning: false,
    );
    yield state;
  }

  /// Run the Agent approach (uses existing service)
  Future<ApproachResult> _runAgent(String patientId, String query) async {
    final startTime = DateTime.now();
    try {
      String? lastResponse;
      await for (final agentState in _agentService.processQuery(patientId, query)) {
        lastResponse = agentState.response;
      }
      return ApproachResult(
        approach: 'agent',
        response: lastResponse ?? 'No response',
        duration: DateTime.now().difference(startTime),
        isComplete: true,
      );
    } catch (e) {
      return ApproachResult(
        approach: 'agent',
        response: '',
        duration: DateTime.now().difference(startTime),
        isComplete: true,
        error: e.toString(),
      );
    }
  }

  /// Run LLM Direct approach (context stuffing - all patient data in prompt)
  Future<ApproachResult> _runLlmDirect(String patientId, String query) async {
    final startTime = DateTime.now();
    try {
      if (_llmModel == null) {
        return ApproachResult(
          approach: 'llm',
          response: '',
          duration: DateTime.now().difference(startTime),
          isComplete: true,
          error: 'LLM model not initialized',
        );
      }

      // Fetch all patient data (context stuffing)
      final patientContext = await _buildPatientContext(patientId);

      final messages = [
        cactus.ChatMessage(
          role: 'system',
          content: 'You are a medical assistant. Answer questions based on the provided patient data. Be concise and accurate.',
        ),
        cactus.ChatMessage(
          role: 'user',
          content: '''$patientContext

Question: $query

Answer based on the patient data above:''',
        ),
      ];

      final result = await _llmModel!.generateCompletion(
        messages: messages,
        params: cactus.CactusCompletionParams(maxTokens: 256, temperature: 0.5),
      );

      return ApproachResult(
        approach: 'llm',
        response: _cleanResponse(result.response),
        duration: DateTime.now().difference(startTime),
        isComplete: true,
      );
    } catch (e) {
      return ApproachResult(
        approach: 'llm',
        response: '',
        duration: DateTime.now().difference(startTime),
        isComplete: true,
        error: e.toString(),
      );
    }
  }

  /// Build full patient context for LLM Direct (context stuffing)
  Future<String> _buildPatientContext(String patientId) async {
    final buffer = StringBuffer();
    buffer.writeln('=== PATIENT DATA ===\n');

    try {
      // Patient info
      final manifest = await _fhirService.getPatientManifest(patientId);
      final patientInfo = manifest['patient'] as Map<String, dynamic>?;
      if (patientInfo != null) {
        buffer.writeln('PATIENT: ${patientInfo['name']}, Age: ${patientInfo['age']}, Gender: ${patientInfo['gender']}');
        buffer.writeln();
      }

      // Conditions
      final conditions = await _fhirService.getConditions(patientId);
      final condList = conditions['conditions'] as List<dynamic>? ?? [];
      if (condList.isNotEmpty) {
        buffer.writeln('CONDITIONS:');
        for (final c in condList) {
          final cond = c as Map<String, dynamic>;
          buffer.writeln('- ${cond['name']} (${cond['isActive'] == true ? 'active' : 'resolved'})');
        }
        buffer.writeln();
      }

      // Medications
      final medications = await _fhirService.getMedications(patientId);
      final medList = medications['medications'] as List<dynamic>? ?? [];
      if (medList.isNotEmpty) {
        buffer.writeln('MEDICATIONS:');
        for (final m in medList) {
          final med = m as Map<String, dynamic>;
          buffer.writeln('- ${med['name']}${med['dosage'] != null ? ' (${med['dosage']})' : ''}');
        }
        buffer.writeln();
      }

      // Allergies
      final allergies = await _fhirService.getAllergies(patientId);
      final allergyList = allergies['allergies'] as List<dynamic>? ?? [];
      if (allergyList.isNotEmpty) {
        buffer.writeln('ALLERGIES:');
        for (final a in allergyList) {
          final allergy = a as Map<String, dynamic>;
          buffer.writeln('- ${allergy['allergen']}${allergy['isHighCriticality'] == true ? ' (HIGH RISK)' : ''}');
        }
        buffer.writeln();
      }

      // Observations (vitals, labs)
      final observations = await _fhirService.getObservations(patientId);
      final obsList = observations['observations'] as List<dynamic>? ?? [];
      if (obsList.isNotEmpty) {
        buffer.writeln('OBSERVATIONS/VITALS:');
        for (final o in obsList) {
          final obs = o as Map<String, dynamic>;
          buffer.writeln('- ${obs['name']}: ${obs['value']} ${obs['unit'] ?? ''}');
        }
        buffer.writeln();
      }
    } catch (e) {
      debugPrint('Error building patient context: $e');
    }

    return buffer.toString();
  }

  /// Run RAG approach (embed query, retrieve chunks, generate)
  Future<ApproachResult> _runRag(String patientId, String query) async {
    final startTime = DateTime.now();
    try {
      if (_ragModel == null) {
        return ApproachResult(
          approach: 'rag',
          response: '',
          duration: DateTime.now().difference(startTime),
          isComplete: true,
          error: 'RAG model not initialized',
        );
      }

      // Step 1: Ensure patient data is embedded
      await _ensurePatientEmbedded(patientId);

      // Step 2: Embed query
      final queryEmbedding = await _ragModel!.generateEmbedding(text: query);
      if (!queryEmbedding.success) {
        throw Exception('Failed to embed query');
      }

      // Step 3: Find top-k similar chunks
      final chunks = _patientEmbeddings[patientId] ?? [];
      final rankedChunks = _rankChunks(queryEmbedding.embeddings, chunks, topK: 5);

      // Step 4: Generate response with retrieved context
      final context = rankedChunks.map((c) => c.text).join('\n\n');
      final messages = [
        cactus.ChatMessage(
          role: 'system',
          content: 'You are a medical assistant. Answer based ONLY on the provided context.',
        ),
        cactus.ChatMessage(
          role: 'user',
          content: '''Context:
$context

Question: $query

Answer based only on the context above:''',
        ),
      ];

      final result = await _ragModel!.generateCompletion(
        messages: messages,
        params: cactus.CactusCompletionParams(maxTokens: 256, temperature: 0.3),
      );

      return ApproachResult(
        approach: 'rag',
        response: _cleanResponse(result.response),
        duration: DateTime.now().difference(startTime),
        isComplete: true,
        retrievedChunks: rankedChunks.map((c) => c.text).toList(),
      );
    } catch (e) {
      return ApproachResult(
        approach: 'rag',
        response: '',
        duration: DateTime.now().difference(startTime),
        isComplete: true,
        error: e.toString(),
      );
    }
  }

  /// Ensure patient data is embedded for RAG
  Future<void> _ensurePatientEmbedded(String patientId) async {
    if (_patientEmbeddings.containsKey(patientId)) return;

    debugPrint('Embedding patient data for RAG...');
    final chunks = <_EmbeddedChunk>[];

    // Get patient data and chunk it
    final manifest = await _fhirService.getPatientManifest(patientId);
    final patientInfo = manifest['patient'] as Map<String, dynamic>?;

    if (patientInfo != null) {
      final text = 'Patient: ${patientInfo['name']}, Age: ${patientInfo['age']}, Gender: ${patientInfo['gender']}';
      final embedding = await _ragModel!.generateEmbedding(text: text);
      if (embedding.success) {
        chunks.add(_EmbeddedChunk(text: text, embedding: embedding.embeddings));
      }
    }

    // Get conditions
    try {
      final conditions = await _fhirService.getConditions(patientId);
      for (final cond in (conditions['conditions'] as List<dynamic>? ?? [])) {
        final c = cond as Map<String, dynamic>;
        final text = 'Condition: ${c['name']} (${c['isActive'] == true ? 'active' : 'resolved'})';
        final embedding = await _ragModel!.generateEmbedding(text: text);
        if (embedding.success) {
          chunks.add(_EmbeddedChunk(text: text, embedding: embedding.embeddings));
        }
      }
    } catch (_) {}

    // Get medications
    try {
      final medications = await _fhirService.getMedications(patientId);
      for (final med in (medications['medications'] as List<dynamic>? ?? [])) {
        final m = med as Map<String, dynamic>;
        final text = 'Medication: ${m['name']} - ${m['dosage'] ?? 'dosage not specified'}';
        final embedding = await _ragModel!.generateEmbedding(text: text);
        if (embedding.success) {
          chunks.add(_EmbeddedChunk(text: text, embedding: embedding.embeddings));
        }
      }
    } catch (_) {}

    // Get observations
    try {
      final observations = await _fhirService.getObservations(patientId);
      for (final obs in (observations['observations'] as List<dynamic>? ?? [])) {
        final o = obs as Map<String, dynamic>;
        final text = '${o['name']}: ${o['value']} ${o['unit'] ?? ''}';
        final embedding = await _ragModel!.generateEmbedding(text: text);
        if (embedding.success) {
          chunks.add(_EmbeddedChunk(text: text, embedding: embedding.embeddings));
        }
      }
    } catch (_) {}

    // Get allergies
    try {
      final allergies = await _fhirService.getAllergies(patientId);
      for (final allergy in (allergies['allergies'] as List<dynamic>? ?? [])) {
        final a = allergy as Map<String, dynamic>;
        final text = 'Allergy: ${a['allergen']}${a['isHighCriticality'] == true ? ' (HIGH RISK)' : ''}';
        final embedding = await _ragModel!.generateEmbedding(text: text);
        if (embedding.success) {
          chunks.add(_EmbeddedChunk(text: text, embedding: embedding.embeddings));
        }
      }
    } catch (_) {}

    _patientEmbeddings[patientId] = chunks;
    debugPrint('Embedded ${chunks.length} chunks for patient $patientId');
  }

  /// Rank chunks by cosine similarity to query
  List<_EmbeddedChunk> _rankChunks(
    List<double> queryEmbedding,
    List<_EmbeddedChunk> chunks,
    {int topK = 5}
  ) {
    final scored = chunks.map((chunk) {
      final similarity = _cosineSimilarity(queryEmbedding, chunk.embedding);
      return _ScoredChunk(chunk: chunk, score: similarity);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(topK).map((s) => s.chunk).toList();
  }

  /// Calculate cosine similarity between two vectors
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  String _cleanResponse(String response) {
    return response
        .replaceAll('<think>', '')
        .replaceAll('</think>', '')
        .replaceAll('<end_of_turn>', '')
        .replaceAll('<|im_end|>', '')
        .replaceAll('<|endoftext|>', '')
        .trim();
  }

  void dispose() {
    _llmModel?.unload();
    _ragModel?.unload();
    _llmModel = null;
    _ragModel = null;
    _patientEmbeddings.clear();
    _initialized = false;
  }
}

/// Internal class for embedded chunks
class _EmbeddedChunk {
  final String text;
  final List<double> embedding;

  _EmbeddedChunk({required this.text, required this.embedding});
}

/// Internal class for scored chunks
class _ScoredChunk {
  final _EmbeddedChunk chunk;
  final double score;

  _ScoredChunk({required this.chunk, required this.score});
}
