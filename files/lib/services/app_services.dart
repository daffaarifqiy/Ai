import 'dart:io';
import 'dart:convert';
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

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ChatSession.fromMap(Map<String, dynamic> m) => ChatSession(
        id: m['id'] as String,
        title: m['title'] as String,
        createdAt: DateTime.parse(m['createdAt'] as String),
      );
}

class ChatStorage {
  static const String _boxSessions = 'chat_sessions';
  static const String _boxMessages = 'chat_messages';

  // Sesi Baru
  static Future<ChatSession> createSession() async {
    final session = ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Obrolan Baru',
      createdAt: DateTime.now(),
    );
    await Hive.box(_boxSessions).put(session.id, session.toMap());
    return session;
  }

  // Ambil Semua Sesi
  static List<ChatSession> getSessions() {
    final list = Hive.box(_boxSessions)
        .values
        .map((e) => ChatSession.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  // Simpan Pesan
  static Future<void> saveMessage(String sessionId, ChatMessage msg) async {
    final box = Hive.box(_boxMessages);
    List<dynamic> msgs = box.get(sessionId, defaultValue: []);
    msgs.add(msg.toMap());
    await box.put(sessionId, msgs);

    // Update judul sesi jika masih "Obrolan Baru" dan pesan pertama dari user
    if (msg.role == 'user') {
      final sessBox = Hive.box(_boxSessions);
      final sessData = sessBox.get(sessionId);
      if (sessData != null) {
        final sess = ChatSession.fromMap(Map<String, dynamic>.from(sessData));
        if (sess.title == 'Obrolan Baru') {
          final newTitle = msg.content.length > 25
              ? '${msg.content.substring(0, 25)}...'
              : msg.content;
          await sessBox.put(sessionId, ChatSession(
            id: sess.id,
            title: newTitle,
            createdAt: sess.createdAt,
          ).toMap());
        }
      }
    }
  }

  // Ambil Pesan Berdasarkan Sesi
  static List<ChatMessage> getMessages(String sessionId) {
    final box = Hive.box(_boxMessages);
    final List<dynamic> msgs = box.get(sessionId, defaultValue: []);
    return msgs
        .map((e) => ChatMessage.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<void> deleteSession(String sessionId) async {
    await Hive.box(_boxSessions).delete(sessionId);
    await Hive.box(_boxMessages).delete(sessionId);
  }
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
}

class ModelService {
  // URL Model Baru: Qwen2.5-Coder-1.5B-abliterated (Q4_K_M)
  static const String modelUrl =
      'https://huggingface.co/huihui-ai/Qwen2.5-Coder-1.5B-Instruct-abliterated-GGUF/resolve/main/Qwen2.5-Coder-1.5B-Instruct-abliterated.Q4_K_M.gguf';
  static const String modelFileName = 'qwen2.5-coder-1.5b-abliterated.gguf';
  static const int minValidSize = 100000000; // ~100 MB validasi minimal

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
