import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:llama_flutter_android/llama_flutter_android.dart' as llama;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatMessage {
  final String id;
  final String role;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    String? id,
    required this.role,
    required this.content,
    DateTime? timestamp,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        id: m['id'] as String?,
        role: m['role'] as String,
        content: m['content'] as String,
        timestamp: DateTime.parse(m['timestamp'] as String),
      );
}

class PermissionService {
  static Future<bool> requestStorage() async {
    if (!Platform.isAndroid) return true;
    final info = await DeviceInfoPlugin().androidInfo;
    if (info.version.sdkInt >= 30) {
      return (await Permission.manageExternalStorage.request()).isGranted;
    }
    return (await Permission.storage.request()).isGranted;
  }

  static Future<bool> hasStorage() async {
    if (!Platform.isAndroid) return true;
    final info = await DeviceInfoPlugin().androidInfo;
    if (info.version.sdkInt >= 30) {
      return Permission.manageExternalStorage.isGranted;
    }
    return Permission.storage.isGranted;
  }

  static Future<void> openSettings() => openAppSettings();
}

class ModelService {
  static const String modelUrl =
      'https://huggingface.co/prithivMLmods/Qwen3-4B-abliterated-f32-GGUFs/resolve/main/Qwen3-4B-abliterated.Q4_K_M.gguf';
  static const String modelFileName = 'qwen3-4b-abliterated-q4_k_m.gguf';
  static const int minValidSize = 1000000000;

  static Future<Directory> getModelDir() async {
    final base = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/xdfaaa_ai_models');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<String> getModelPath() async =>
      '${(await getModelDir()).path}/$modelFileName';

  static Future<bool> isModelDownloaded() async {
    final f = File(await getModelPath());
    return await f.exists() && await f.length() > minValidSize;
  }

  static Future<void> downloadModel({
    required void Function(int received, int total) onProgress,
  }) async {
    final file = File(await getModelPath());
    if (await file.exists()) await file.delete();
    final client = http.Client();
    final res = await client.send(http.Request('GET', Uri.parse(modelUrl)));
    final total = res.contentLength ?? 0;
    int received = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      }
      await sink.flush();
    } finally {
      await sink.close();
      client.close();
    }
  }

  static Future<llama.LlamaController> loadModel() async {
    final path = await getModelPath();
    final c = llama.LlamaController();
    int gpuLayers = 0;
    try {
      final gpu = await c.detectGpu();
      gpuLayers = gpu.recommendedGpuLayers;
    } catch (_) {}
    await c.loadModel(
      modelPath: path,
      threads: 4,
      contextSize: 4096,
      gpuLayers: gpuLayers,
    );
    return c;
  }
}

class ChatStorage {
  static const String _box = 'messages';

  static Future<void> save(ChatMessage m) async =>
      Hive.box(_box).put(m.id, m.toMap());

  static List<ChatMessage> loadAll() {
    final list = Hive.box(_box)
        .values
        .map((e) => ChatMessage.fromMap(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  static Future<void> clear() async => Hive.box(_box).clear();
}
