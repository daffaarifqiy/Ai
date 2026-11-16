import 'dart:async';

import 'package:flutter/material.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart' as llama;

import '../services/app_services.dart';
import '../widgets/chat_widgets.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  final llama.LlamaController controller;

  const ChatScreen({super.key, required this.controller});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  StreamSubscription<String>? _sub;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _messages.addAll(ChatStorage.loadAll());
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _generating) return;
    _input.clear();

    final userMsg = ChatMessage(role: 'user', content: text);
    final botMsg = ChatMessage(role: 'assistant', content: '');
    setState(() {
      _messages.add(userMsg);
      _messages.add(botMsg);
      _generating = true;
    });
    await ChatStorage.save(userMsg);
    _scrollToBottom();

    final hist = _messages.where((m) => m.id != botMsg.id).toList();
    final recent = hist.length > 12 ? hist.sublist(hist.length - 12) : hist;

    final chatHistory = <llama.ChatMessage>[
      llama.ChatMessage(
        role: 'system',
        content:
            'Anda adalah xdfaaa ai, asisten AI lokal. Jawab jelas, ringkas, '
            'dan pakai bahasa yang sama dengan pengguna.',
      ),
      ...recent.map(
          (m) => llama.ChatMessage(role: m.role, content: m.content)),
    ];

    final buffer = StringBuffer();
    _sub = widget.controller
        .generateChat(
      messages: chatHistory,
      template: 'chatml',
      maxTokens: 1024,
      temperature: 0.7,
      topP: 0.9,
    )
        .listen(
      (token) {
        buffer.write(token);
        final idx = _messages.indexWhere((m) => m.id == botMsg.id);
        if (idx == -1) return;
        setState(() {
          _messages[idx] = ChatMessage(
            id: botMsg.id,
            role: 'assistant',
            content: buffer.toString(),
            timestamp: botMsg.timestamp,
          );
        });
        _scrollToBottom();
      },
      onDone: () async {
        await ChatStorage.save(ChatMessage(
          id: botMsg.id,
          role: 'assistant',
          content: buffer.toString(),
          timestamp: botMsg.timestamp,
        ));
        setState(() => _generating = false);
        _sub = null;
      },
      onError: (e) {
        setState(() => _generating = false);
        _sub = null;
        _showError('Gagal: $e');
      },
    );
  }

  Future<void> _stop() async {
    await widget.controller.stop();
    await _sub?.cancel();
    _sub = null;
    setState(() => _generating = false);
  }

  Future<void> _newChat() async {
    await _stop();
    await ChatStorage.clear();
    setState(() => _messages.clear());
  }

  void _showError(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  void dispose() {
    _sub?.cancel();
    widget.controller.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipOval(
              child: Image.asset(
                'Meta_AI_hacker_logo_cutout_20261116_221322.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.smart_toy,
                  color: Colors.deepPurpleAccent,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('xdfaaa ai'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Chat baru',
            onPressed: _generating ? null : _newChat,
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            tooltip: 'Pengaturan',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text('Mulai percakapan dengan xdfaaa ai',
                        style: TextStyle(color: Colors.white54)),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final last = i == _messages.length - 1;
                      return MessageBubble(
                        message: _messages[i],
                        isStreaming: _generating &&
                            last &&
                            _messages[i].role == 'assistant',
                      );
                    },
                  ),
          ),
          if (_generating)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Ketik pesan...',
                        filled: true,
                        fillColor: const Color(0xFF161B22),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _generating
                      ? IconButton.filled(
                          onPressed: _stop,
                          icon: const Icon(Icons.stop),
                        )
                      : IconButton.filled(
                          onPressed: _send,
                          icon: const Icon(Icons.send),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
