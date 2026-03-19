/// ============================================
/// CACTUS SDK - On-Device LLM Inference
/// ============================================
///
/// Run LLMs locally on mobile/desktop
/// All data stays on device - complete privacy

import 'package:cactus/cactus.dart' as cactus;

// ---------------------------------------------
// 1. Initialize Model
// ---------------------------------------------
Future<cactus.CactusLM> initializeModel() async {
  final model = cactus.CactusLM();

  // Download model (one-time)
  await model.downloadModel(
    model: 'qwen3-0.6',
    downloadProcessCallback: (progress, status, isError) {
      print('Download: $progress% - $status');
    },
  );

  // Load into memory
  await model.initializeModel(
    params: cactus.CactusInitParams(model: 'qwen3-0.6'),
  );

  return model;
}

// ---------------------------------------------
// 2. Generate Completion (Chat)
// ---------------------------------------------
Future<String> generateCompletion(cactus.CactusLM model, String userMessage) async {
  final result = await model.generateCompletion(
    messages: [
      cactus.ChatMessage(
        role: 'system',
        content: 'You are a medical assistant.',
      ),
      cactus.ChatMessage(
        role: 'user',
        content: userMessage,
      ),
    ],
    params: cactus.CactusCompletionParams(
      maxTokens: 256,
      temperature: 0.5,
    ),
  );

  return result.response;
}

// ---------------------------------------------
// 3. Streaming Completion (Real-time output)
// ---------------------------------------------
Stream<String> generateCompletionStream(cactus.CactusLM model, String userMessage) async* {
  final streamedResult = await model.generateCompletionStream(
    messages: [
      cactus.ChatMessage(role: 'user', content: userMessage),
    ],
    params: cactus.CactusCompletionParams(maxTokens: 512),
  );

  // Yield tokens as they're generated
  await for (final token in streamedResult.stream) {
    yield token;  // Real-time output to UI
  }
}

// ---------------------------------------------
// 4. Generate Embeddings (for RAG)
// ---------------------------------------------
Future<List<double>> generateEmbedding(cactus.CactusLM model, String text) async {
  final result = await model.generateEmbedding(text: text);
  return result.embeddings;  // Vector of 384-1024 dimensions
}

// ---------------------------------------------
// 5. Tool Calling (Function Calling)
// ---------------------------------------------
Future<List<cactus.ToolCallResult>> callWithTools(cactus.CactusLM model, String query) async {
  final result = await model.generateCompletion(
    messages: [
      cactus.ChatMessage(role: 'user', content: query),
    ],
    params: cactus.CactusCompletionParams(
      maxTokens: 256,
      tools: [
        cactus.CactusTool(
          name: 'get_medications',
          description: 'Retrieve patient medications',
          parameters: cactus.ToolParametersSchema(
            properties: {
              'patient_id': cactus.ToolParameter(
                type: 'string',
                description: 'Patient ID',
                required: true,
              ),
            },
          ),
        ),
        cactus.CactusTool(
          name: 'get_conditions',
          description: 'Retrieve patient diagnoses',
          parameters: cactus.ToolParametersSchema(
            properties: {
              'patient_id': cactus.ToolParameter(
                type: 'string',
                required: true,
              ),
            },
          ),
        ),
      ],
    ),
  );

  // LLM returns structured tool calls
  return result.toolCalls;
  // Example: [{name: 'get_medications', arguments: {patient_id: '123'}}]
}


// ---------------------------------------------
// Example Usage
// ---------------------------------------------
void main() async {
  // Initialize
  final model = await initializeModel();

  // Simple completion
  final response = await generateCompletion(model, 'What is diabetes?');
  print(response);

  // Streaming (for real-time UI)
  await for (final token in generateCompletionStream(model, 'Explain hypertension')) {
    print(token);  // Prints each token as generated
  }

  // Embeddings (for RAG)
  final embedding = await generateEmbedding(model, 'Diabetes mellitus type 2');
  print('Embedding dimensions: ${embedding.length}');

  // Tool calling
  final tools = await callWithTools(model, 'What medications is patient 123 taking?');
  for (final tool in tools) {
    print('Tool: ${tool.name}, Args: ${tool.arguments}');
  }
}
