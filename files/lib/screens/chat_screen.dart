import 'dart:async';
import 'package:flutter/material.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart' as llama;
import '../services/app_services.dart';
import '../widgets/chat_widgets.dart';

class ChatScreen extends StatefulWidget {
  final llama.LlamaController controller;
  const ChatScreen({super.key, required this.controller});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  
  List<ChatSession> _sessions = [];
  List<ChatMessage> _messages = [];
  ChatSession? _currentSession;
  
  StreamSubscription<String>? _sub;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  void _loadSessions() {
    _sessions = ChatStorage.getSessions();
    if (_sessions.isNotEmpty) {
      _currentSession = _sessions.first;
      _messages = ChatStorage.getMessages(_currentSession!.id);
    } else {
      _createNewChat();
    }
    setState(() {});
    _scrollToBottom();
  }

  void _createNewChat() async {
    final newSess = await ChatStorage.createSession();
    setState(() {
      _sessions.insert(0, newSess);
      _currentSession = newSess;
      _messages = [];
    });
    _scrollToBottom();
  }

  void _openSession(ChatSession session) {
    setState(() {
      _currentSession = session;
      _messages = ChatStorage.getMessages(session.id);
    });
    Navigator.pop(context);
    _scrollToBottom();
  }

  void _deleteSession(ChatSession session) async {
    await ChatStorage.deleteSession(session.id);
    _loadSessions();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  // ==========================================
  // LOGIKA UTAMA: KIRIM & EDIT PESAN
  // ==========================================
  
  Future<void> _sendMessage() async {
    final text = _input.text.trim();
    if (text.isEmpty || _generating || _currentSession == null) return;
    _input.clear();

    final userMsg = ChatMessage(role: 'user', content: text);
    setState(() {
      _messages.add(userMsg);
    });
    
    await ChatStorage.saveMessage(_currentSession!.id, userMsg);
    _scrollToBottom();
    
    await _generateAIResponse();
  }

  void _editMessage(int index, String newText) {
    if (_generating) return;

    // 1. Potong history chat dari pesan yang diedit (hapus pesan lama & balasan AI setelahnya)
    final truncatedMessages = _messages.sublist(0, index);
    
    // 2. Buat pesan baru yang sudah diedit
    final editedMsg = ChatMessage(role: 'user', content: newText);
    truncatedMessages.add(editedMsg);

    setState(() {
      _messages = truncatedMessages;
    });

    // 3. Simpan state baru ke Hive (overwrite)
    ChatStorage.overwriteMessages(_currentSession!.id, _messages);
    
    // 4. Minta AI merespons ulang
    _generateAIResponse();
  }

  Future<void> _generateAIResponse() async {
    if (_currentSession == null) return;

    final botMsg = ChatMessage(role: 'assistant', content: '');
    setState(() {
      _messages.add(botMsg);
      _generating = true;
    });
    _scrollToBottom();

    // Ambil 10 pesan terakhir untuk konteks
    final hist = _messages.where((m) => m.id != botMsg.id).toList();
    final recent = hist.length > 10 ? hist.sublist(hist.length - 10) : hist;

    final chatHistory = <llama.ChatMessage>[
      llama.ChatMessage(role: 'system', content: 'Anda adalah xdfaaa ai, asisten coding dan AI pintar. Jawab jelas dan pakai format markdown.'),
      ...recent.map((m) => llama.ChatMessage(role: m.role, content: m.content)),
    ];

    final buffer = StringBuffer();
    _sub = widget.controller.generateChat(
      messages: chatHistory,
      template: 'chatml',
      maxTokens: 2048,
      temperature: 0.7,
    ).listen(
      (token) {
        buffer.write(token);
        final idx = _messages.indexWhere((m) => m.id == botMsg.id);
        if (idx == -1) return;
        setState(() {
          _messages[idx] = ChatMessage(id: botMsg.id, role: 'assistant', content: buffer.toString(), timestamp: botMsg.timestamp);
        });
        _scrollToBottom();
      },
      onDone: () async {
        await ChatStorage.saveMessage(_currentSession!.id, ChatMessage(id: botMsg.id, role: 'assistant', content: buffer.toString(), timestamp: botMsg.timestamp));
        setState(() => _generating = false);
        _sub = null;
      },
      onError: (e) {
        setState(() => _generating = false);
        _sub = null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('xdfaaa ai'),
        actions: [
          IconButton(
            onPressed: _generating ? null : _createNewChat,
            icon: const Icon(Icons.add_comment),
            tooltip: 'Chat Baru',
          ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          color: const Color(0xFF0D1117),
          child: ListView.builder(
            itemCount: _sessions.length,
            itemBuilder: (ctx, i) {
              final sess = _sessions[i];
              final isSelected = sess.id == _currentSession?.id;
              return ListTile(
                selected: isSelected,
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(sess.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, size: 18),
                  onPressed: () => _deleteSession(sess),
                ),
                onTap: () => _openSession(sess),
              );
            },
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('Mulai percakapan baru...', style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final last = i == _messages.length - 1;
                      return MessageBubble(
                        message: _messages[i],
                        isStreaming: _generating && last && _messages[i].role == 'assistant',
                        // Tambahkan callback edit khusus untuk pesan user
                        onEdit: _messages[i].role == 'user' && !_generating
                            ? () => _showEditDialog(i, _messages[i].content)
                            : null,
                      );
                    },
                  ),
          ),
          if (_generating) const LinearProgressIndicator(minHeight: 2),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Ketik pesan...',
                        filled: true,
                        fillColor: const Color(0xFF161B22),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _generating ? null : _sendMessage,
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

  // Dialog untuk mengedit pesan
  void _showEditDialog(int index, String currentText) {
    final editCtrl = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Edit Pesan', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: editCtrl,
          maxLines: null,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            filled: true,
            fillColor: Color(0xFF0D1117),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (editCtrl.text.trim().isNotEmpty && editCtrl.text != currentText) {
                _editMessage(index, editCtrl.text.trim());
              }
            },
            child: const Text('Simpan & Kirim Ulang'),
          ),
        ],
      ),
    );
  }
}
