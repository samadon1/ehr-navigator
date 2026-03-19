import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Model purpose enum
enum ModelPurpose { routing, reasoning, embedding }

/// Configuration for a downloadable model
class ModelConfig {
  final String name;
  final String displayName;
  final String url;
  final int expectedSizeBytes;
  final ModelPurpose purpose;
  final bool isGguf;

  const ModelConfig({
    required this.name,
    required this.displayName,
    required this.url,
    required this.expectedSizeBytes,
    required this.purpose,
    this.isGguf = false,
  });

  String get sizeDisplay {
    if (expectedSizeBytes >= 1000000000) {
      return '${(expectedSizeBytes / 1000000000).toStringAsFixed(1)} GB';
    }
    return '${(expectedSizeBytes / 1000000).toStringAsFixed(0)} MB';
  }
}

class ModelDownloader {
  // Legacy model (backward compatibility)
  static const ModelConfig lfm2Rag = ModelConfig(
    name: 'lfm2-1.2b-rag',
    displayName: 'LFM2 1.2B RAG',
    url: 'https://huggingface.co/Cactus-Compute/LFM2-1.2B-RAG/resolve/main/weights/lfm2-1.2b-rag.zip',
    expectedSizeBytes: 1170000000, // ~1.17 GB
    purpose: ModelPurpose.reasoning,
  );

  // FunctionGemma for tool routing (CACT INT4 format - requires newer Cactus)
  static const ModelConfig functionGemma = ModelConfig(
    name: 'functiongemma-270m-it',
    displayName: 'FunctionGemma 270M',
    url: 'https://huggingface.co/Cactus-Compute/functiongemma-270m-it/resolve/main/weights/functiongemma-270m-it-int4.zip',
    expectedSizeBytes: 138000000, // ~138 MB
    purpose: ModelPurpose.routing,
  );

  // Qwen3 0.6B for tool routing (raw tensor format - works with Cactus v0.0.3)
  static const ModelConfig qwen3Routing = ModelConfig(
    name: 'qwen3-0.6',
    displayName: 'Qwen3 0.6B',
    url: 'https://huggingface.co/Cactus-Compute/Qwen3-0.6B/resolve/main/weights/qwen3-0.6.zip',
    expectedSizeBytes: 400000000, // ~400 MB
    purpose: ModelPurpose.routing,
  );

  // Gemma3 270M for reasoning (raw tensor format - works with Cactus v0.0.3)
  static const ModelConfig gemma3Reasoning = ModelConfig(
    name: 'gemma3-270m',
    displayName: 'Gemma3 270M',
    url: 'https://huggingface.co/Cactus-Compute/gemma3-270m/resolve/main/weights/gemma3-270m.zip',
    expectedSizeBytes: 550000000, // ~550 MB
    purpose: ModelPurpose.reasoning,
  );

  // MedGemma for medical reasoning (CACT INT4 format - requires newer Cactus)
  static const ModelConfig medGemma = ModelConfig(
    name: 'medgemma-4b-it-int4',
    displayName: 'MedGemma 4B INT4',
    url: 'https://huggingface.co/samwell/medgemma-4b-it-cactus-int4/resolve/main/medgemma-4b-it-int4.zip',
    expectedSizeBytes: 2880000000, // ~2.88 GB (compressed: 2.7 GB)
    purpose: ModelPurpose.reasoning,
  );

  // All available models
  static const List<ModelConfig> allModels = [
    lfm2Rag,
    functionGemma,
    medGemma,
  ];

  // EHR Navigator required models
  // MedGemma 4B requires 8GB+ RAM (Mac/iPad Pro)
  // For iPhone, use fallback mode (CDS rules still work)
  static const List<ModelConfig> ehrModels = [
    functionGemma,
    medGemma, // ~3.2 GB - works on Mac/iPad Pro with 8GB+ RAM
  ];

  /// Get the path where a model should be stored
  static Future<String> getModelPath([ModelConfig? model]) async {
    final dir = await getApplicationDocumentsDirectory();
    final modelName = model?.name ?? lfm2Rag.name;
    return '${dir.path}/models/$modelName';
  }

  /// Check if a specific model is downloaded
  static Future<bool> isModelDownloaded([ModelConfig? model]) async {
    final modelPath = await getModelPath(model);
    final modelDir = Directory(modelPath);

    if (model?.isGguf == true) {
      // For GGUF files, check if the .gguf file exists
      final ggufFile = File('$modelPath/${model!.name}.gguf');
      return ggufFile.existsSync();
    }

    if (!await modelDir.exists()) return false;
    // Check if config.txt exists (indicates complete download for weight folders)
    final configFile = File('$modelPath/config.txt');
    return configFile.existsSync();
  }

  /// Check status of all EHR models
  static Future<Map<ModelConfig, bool>> checkEhrModelsStatus() async {
    final status = <ModelConfig, bool>{};
    for (final model in ehrModels) {
      status[model] = await isModelDownloaded(model);
    }
    return status;
  }

  /// Download a specific model with progress callback
  static Future<String> downloadModel({
    ModelConfig? model,
    required Function(double progress, String status) onProgress,
  }) async {
    model ??= lfm2Rag;
    final modelPath = await getModelPath(model);
    final modelDir = Directory(modelPath);

    // Check if already downloaded
    if (await isModelDownloaded(model)) {
      onProgress(1.0, 'Model ready');
      return modelPath;
    }

    // Create models directory
    final modelsDir = Directory('${(await getApplicationDocumentsDirectory()).path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    try {
      if (model.isGguf) {
        return await _downloadGgufModel(model, modelPath, onProgress);
      } else {
        return await _downloadZipModel(model, modelPath, onProgress);
      }
    } catch (e) {
      // Clean up on error
      if (await modelDir.exists()) {
        await modelDir.delete(recursive: true);
      }
      rethrow;
    }
  }

  /// Download a GGUF model file directly
  static Future<String> _downloadGgufModel(
    ModelConfig model,
    String modelPath,
    Function(double progress, String status) onProgress,
  ) async {
    final modelDir = Directory(modelPath);
    await modelDir.create(recursive: true);

    final ggufPath = '$modelPath/${model.name}.gguf';
    final ggufFile = File(ggufPath);

    onProgress(0.0, 'Connecting...');

    final request = http.Request('GET', Uri.parse(model.url));
    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      throw Exception('Failed to download model: HTTP ${response.statusCode}');
    }

    final contentLength = response.contentLength ?? model.expectedSizeBytes;
    var downloadedBytes = 0;

    final sink = ggufFile.openWrite();

    await for (final chunk in response.stream) {
      sink.add(chunk);
      downloadedBytes += chunk.length;
      final progress = downloadedBytes / contentLength;
      final downloadedMB = (downloadedBytes / 1024 / 1024).toStringAsFixed(1);
      final totalMB = (contentLength / 1024 / 1024).toStringAsFixed(0);
      onProgress(progress * 0.95, 'Downloading ${model.displayName}... $downloadedMB / $totalMB MB');
    }

    await sink.close();

    // Create config.txt for GGUF models (required by Cactus)
    onProgress(0.98, 'Creating config...');
    final configFile = File('$modelPath/config.txt');
    final configContent = _generateGgufConfig(model, ggufPath);
    await configFile.writeAsString(configContent);

    onProgress(1.0, 'Model ready');
    debugPrint('GGUF model downloaded to: $ggufPath');
    debugPrint('Config created at: ${configFile.path}');

    return modelPath;
  }

  /// Generate config.txt content for a GGUF model
  static String _generateGgufConfig(ModelConfig model, String ggufPath) {
    // Config format expected by Cactus
    final config = StringBuffer();
    config.writeln('model_path=$ggufPath');
    config.writeln('n_ctx=4096');
    config.writeln('n_threads=4');
    config.writeln('n_gpu_layers=99');  // Use GPU acceleration on iOS
    config.writeln('use_mmap=true');
    config.writeln('use_mlock=false');

    // Model-specific settings
    if (model.purpose == ModelPurpose.reasoning) {
      config.writeln('# MedGemma reasoning model');
      config.writeln('rope_freq_base=10000.0');
      config.writeln('rope_freq_scale=1.0');
    }

    return config.toString();
  }

  /// Download and extract a ZIP model
  static Future<String> _downloadZipModel(
    ModelConfig model,
    String modelPath,
    Function(double progress, String status) onProgress,
  ) async {
    final modelDir = Directory(modelPath);
    final modelsDir = Directory('${(await getApplicationDocumentsDirectory()).path}/models');
    final zipPath = '${modelsDir.path}/${model.name}.zip';
    final zipFile = File(zipPath);

    onProgress(0.0, 'Connecting...');

    final request = http.Request('GET', Uri.parse(model.url));
    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      throw Exception('Failed to download model: HTTP ${response.statusCode}');
    }

    final contentLength = response.contentLength ?? model.expectedSizeBytes;
    var downloadedBytes = 0;

    final sink = zipFile.openWrite();

    await for (final chunk in response.stream) {
      sink.add(chunk);
      downloadedBytes += chunk.length;
      final progress = downloadedBytes / contentLength;
      final downloadedMB = (downloadedBytes / 1024 / 1024).toStringAsFixed(1);
      final totalMB = (contentLength / 1024 / 1024).toStringAsFixed(0);
      onProgress(progress * 0.8, 'Downloading ${model.displayName}... $downloadedMB / $totalMB MB');
    }

    await sink.close();
    onProgress(0.8, 'Extracting model...');

    // Create model directory
    if (await modelDir.exists()) {
      await modelDir.delete(recursive: true);
    }
    await modelDir.create(recursive: true);

    // Extract the zip file using archive v4 API
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    var extractedCount = 0;
    final totalFiles = archive.files.where((f) => f.isFile).length;

    for (final file in archive.files) {
      if (file.isFile) {
        var filename = file.name;

        // Strip leading folder name if present (e.g., "medgemma-4b-it-int4/config.txt" -> "config.txt")
        if (filename.contains('/')) {
          final parts = filename.split('/');
          // If first part matches model name, strip it
          if (parts.first == model.name || parts.first.startsWith(model.name.split('-').first)) {
            filename = parts.sublist(1).join('/');
          }
        }

        if (filename.isEmpty) continue;

        final outPath = '$modelPath/$filename';

        final outFile = File(outPath);
        await outFile.parent.create(recursive: true);

        final data = file.content as List<int>;
        await outFile.writeAsBytes(data);

        extractedCount++;
        final extractProgress = 0.8 + (0.15 * extractedCount / totalFiles);
        onProgress(extractProgress, 'Extracting $extractedCount/$totalFiles files...');
      }
    }
    onProgress(0.95, 'Cleaning up...');

    // Delete zip file to save space
    await zipFile.delete();

    onProgress(1.0, 'Model ready');
    debugPrint('Model downloaded and extracted to: $modelPath');

    return modelPath;
  }

  /// Download all EHR Navigator models
  static Future<void> downloadEhrModels({
    required Function(ModelConfig model, double progress, String status) onProgress,
  }) async {
    for (final model in ehrModels) {
      if (!await isModelDownloaded(model)) {
        await downloadModel(
          model: model,
          onProgress: (progress, status) => onProgress(model, progress, status),
        );
      } else {
        onProgress(model, 1.0, '${model.displayName} ready');
      }
    }
  }

  /// Delete a specific model to free space
  static Future<void> deleteModel([ModelConfig? model]) async {
    final modelPath = await getModelPath(model);
    final modelDir = Directory(modelPath);
    if (await modelDir.exists()) {
      await modelDir.delete(recursive: true);
    }
  }

  /// Get the size of a downloaded model in bytes
  static Future<int> getModelSize([ModelConfig? model]) async {
    final modelPath = await getModelPath(model);
    final modelDir = Directory(modelPath);
    if (!await modelDir.exists()) return 0;

    var size = 0;
    await for (final entity in modelDir.list(recursive: true)) {
      if (entity is File) {
        size += await entity.length();
      }
    }
    return size;
  }

  /// Get total size of all EHR models
  static int get totalEhrModelsSize {
    return ehrModels.fold(0, (sum, model) => sum + model.expectedSizeBytes);
  }

  /// Get total size display for EHR models
  static String get totalEhrModelsSizeDisplay {
    final bytes = totalEhrModelsSize;
    return '${(bytes / 1000000000).toStringAsFixed(1)} GB';
  }
}
