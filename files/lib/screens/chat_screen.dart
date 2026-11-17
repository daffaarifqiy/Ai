import 'dart:async';
import 'package:flutter/material.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart' as llama;
import '../services/app_services.dart';
import '../widgets/chat_widgets.dart';
import 'settings_screen.dart';

enum AIMode { fast, thinking, project }

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
  
  AIMode _currentMode = AIMode.fast;
  String? _activeProject;

  @override
  void initState() {
    super.initState();
    _loadInitialSession();
  }

  Future<void> _loadInitialSession() async {
    _sessions = ChatStorage.getSessions();
    final lastId = await ChatStorage.getLastSessionId();

    if (lastId != null && lastId.isNotEmpty) {
      final found = _sessions.where((s) => s.id == lastId).toList();
      if (found.isNotEmpty) {
        _currentSession = found.first;
        _messages = ChatStorage.getMessages(_currentSession!.id);
        if (_currentSession!.projectName != null) {
          _activeProject = _currentSession!.projectName;
          _currentMode = AIMode.project;
        }
        setState(() {});
        _scrollToBottom();
        return;
      }
    }

    if (_sessions.isNotEmpty) {
      _currentSession = _sessions.first;
      _messages = ChatStorage.getMessages(_currentSession!.id);
      await ChatStorage.saveLastSessionId(_currentSession!.id);
    } else {
      await _createNewChat();
    }
    setState(() {});
    _scrollToBottom();
  }

  void _createNewChat({String? project}) async {
    final newSess = await ChatStorage.createSession(projectName: project);
    setState(() {
      _sessions.insert(0, newSess);
      _currentSession = newSess;
      _messages = [];
      if (project != null) {
        _activeProject = project;
        _currentMode = AIMode.project;
      } else {
        _activeProject = null;
        _currentMode = AIMode.fast;
      }
    });
    await ChatStorage.saveLastSessionId(newSess.id);
    _scrollToBottom();
  }

  void _openSession(ChatSession session) async {
    setState(() {
      _currentSession = session;
      _messages = ChatStorage.getMessages(session.id);
      if (session.projectName != null) {
        _activeProject = session.projectName;
        _currentMode = AIMode.project;
      } else {
        _activeProject = null;
        _currentMode = AIMode.fast;
      }
    });
    await ChatStorage.saveLastSessionId(session.id);
    Navigator.pop(context);
    _scrollToBottom();
  }

  void _deleteSession(ChatSession session) async {
    await ChatStorage.deleteSession(session.id);
    _loadInitialSession();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

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
    final truncatedMessages = _messages.sublist(0, index);
    final editedMsg = ChatMessage(role: 'user', content: newText);
    truncatedMessages.add(editedMsg);

    setState(() {
      _messages = truncatedMessages;
    });
    ChatStorage.overwriteMessages(_currentSession!.id, _messages);
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

    final hist = _messages.where((m) => m.id != botMsg.id).toList();
    final recent = hist.length > 10 ? hist.sublist(hist.length - 10) : hist;

    String sysPrompt = 'Anda adalah xdfaaa ai, asisten coding dan AI pintar. Jawab jelas dan pakai format markdown.';
    
    if (_currentMode == AIMode.thinking) {
      sysPrompt += '\nPENTING: Lakukan proses berpikir (thinking) secara mendalam terlebih dahulu. Bungkus semua proses berpikirmu di dalam tag <think>...</think>. Setelah itu, berikan jawaban akhir di luar tag.';
    } else if (_currentMode == AIMode.project && _activeProject != null) {
      sysPrompt += '\nAnda sedang mengerjakan sebuah PROJECT dengan nama folder: "$_activeProject". Fokuslah membantu user menyelesaikan kode atau tugas terkait project ini.';
    }

    final chatHistory = <llama.ChatMessage>[
      llama.ChatMessage(role: 'system', content: sysPrompt),
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

  void _selectProjectMode() async {
    final projects = await ProjectService.getAllProjects();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        final newProjectCtrl = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: const Text('Pilih Project', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (projects.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Project yang ada', border: OutlineInputBorder()),
                  items: projects.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (val) {
                    Navigator.pop(ctx);
                    _createNewChat(project: val);
                  },
                ),
                const SizedBox(height: 16),
                const Text('ATAU buat baru:', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: newProjectCtrl,
                decoration: const InputDecoration(labelText: 'Nama Folder Project Baru', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: Colors.white54))),
            FilledButton(
              onPressed: () async {
                final newName = newProjectCtrl.text.trim();
                if (newName.isNotEmpty) {
                  await ProjectService.createProject(newName);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _createNewChat(project: newName);
                }
              },
              child: const Text('Buat & Pilih'),
            ),
          ],
        );
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
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.settings),
          ),
          IconButton(
            onPressed: _generating ? null : () => _createNewChat(),
            icon: const Icon(Icons.add_comment),
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
                leading: Icon(sess.projectName != null ? Icons.folder : Icons.chat_bubble_outline),
                title: Text(sess.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: sess.projectName != null ? Text(sess.projectName!, style: const TextStyle(fontSize: 10)) : null,
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
                        onEdit: _messages[i].role == 'user' && !_generating
                            ? () => _showEditDialog(i, _messages[i].content)
                            : null,
                      );
                    },
                  ),
          ),
          if (_generating) const LinearProgressIndicator(minHeight: 2),
          
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                _buildModeChip('Fast', AIMode.fast),
                const SizedBox(width: 8),
                _buildModeChip('Thinking', AIMode.thinking),
                const SizedBox(width: 8),
                _buildModeChip('Project', AIMode.project),
                if (_currentMode == AIMode.project && _activeProject != null) ...[
                  const SizedBox(width: 8),
                  Chip(
                    avatar: const Icon(Icons.folder, size: 14, color: Colors.greenAccent),
                    label: Text(_activeProject!, style: const TextStyle(fontSize: 12, color: Colors.greenAccent)),
                    backgroundColor: Colors.greenAccent.withOpacity(0.1),
                  ),
                ]
              ],
            ),
          ),

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

  Widget _buildModeChip(String label, AIMode mode) {
    final isSelected = _currentMode == mode;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontSize: 12)),
      selected: isSelected,
      selectedColor: const Color(0xFF7C4DFF),
      backgroundColor: const Color(0xFF161B22),
      onSelected: (val) {
        if (val) {
          if (mode == AIMode.project) {
            _selectProjectMode();
          } else {
            setState(() {
              _currentMode = mode;
              _activeProject = null;
            });
          }
        }
      },
    );
  }

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
          decoration: const InputDecoration(filled: true, fillColor: Color(0xFF0D1117), border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: Colors.white54))),
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
