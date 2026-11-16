import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/app_services.dart';

class CodeBlock extends StatelessWidget {
  final String code;
  final String language;

  const CodeBlock({super.key, required this.code, required this.language});

  @override
  Widget build(BuildContext context) {
    final lang = language.isEmpty ? 'text' : language.toLowerCase();
    final isHtml = lang.contains('html') || lang.contains('htm');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Text(lang.toUpperCase(), style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (isHtml)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => HtmlPreviewScreen(htmlContent: code),
                      ));
                    },
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('Jalankan HTML', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(foregroundColor: Colors.greenAccent),
                  ),
                InkWell(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kode disalin'), duration: Duration(seconds: 1)));
                    }
                  },
                  child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.copy, size: 16, color: Colors.white70)),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: HighlightView(code, language: lang, theme: atomOneDarkTheme, padding: EdgeInsets.zero, textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class HtmlPreviewScreen extends StatefulWidget {
  final String htmlContent;
  const HtmlPreviewScreen({super.key, required this.htmlContent});
  @override
  State<HtmlPreviewScreen> createState() => _HtmlPreviewScreenState();
}

class _HtmlPreviewScreenState extends State<HtmlPreviewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(widget.htmlContent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview HTML')),
      body: WebViewWidget(controller: _controller),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isStreaming;
  final VoidCallback? onEdit;

  const MessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.deepPurpleAccent.withOpacity(0.2),
              child: ClipOval(
                child: Image.asset(
                  'assets/ai.jpg.png', // <-- DIUBAH DI SINI
                  width: 36, 
                  height: 36, 
                  fit: BoxFit.cover, 
                  errorBuilder: (_, __, ___) => const Icon(Icons.smart_toy, color: Colors.deepPurpleAccent),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showActionMenu(context, isUser),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isUser ? const Color(0xFF2D1B54) : const Color(0xFF161B22),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 0),
                    bottomRight: Radius.circular(isUser ? 0 : 16),
                  ),
                  border: Border.all(
                    color: isUser ? const Color(0xFF7C4DFF) : Colors.white10,
                    width: 1,
                  ),
                ),
                child: isUser
                    ? SelectableText(message.content, style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.white))
                    : _AssistantContent(content: message.content, isStreaming: isStreaming),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showActionMenu(BuildContext context, bool isUser) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.white),
                title: const Text('Salin Pesan', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: message.content));
                  if (context.mounted) Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pesan disalin')));
                },
              ),
              if (isUser && onEdit != null)
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.white),
                  title: const Text('Edit Pesan', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onEdit!();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AssistantContent extends StatelessWidget {
  final String content;
  final bool isStreaming;
  const _AssistantContent({required this.content, required this.isStreaming});

  @override
  Widget build(BuildContext context) {
    final openThink = RegExp(r'<think(?:ing)?>', caseSensitive: false);
    final closeThink = RegExp(r'</think(?:ing)?>', caseSensitive: false);
    
    bool isThinking = false;
    String mainText = content;

    if (openThink.hasMatch(content) && !closeThink.hasMatch(content)) {
      isThinking = true; 
    } else if (closeThink.hasMatch(content)) {
      mainText = content.replaceAll(RegExp(r'<think(?:ing)?>[\s\S]*?</think(?:ing)?>', caseSensitive: false), '').trim();
    } else {
      mainText = content;
    }

    mainText = mainText.replaceAll(RegExp(r'^(Assistant|User|AI):\s*', caseSensitive: false), '');

    if (isThinking) {
      return const ThinkingAnimation();
    }

    final parts = mainText.split('```');
    final widgets = <Widget>[];

    for (int i = 0; i < parts.length; i++) {
      if (i.isEven) {
        final t = parts[i];
        if (t.trim().isNotEmpty) {
          widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SelectableText(t.trim(), style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.white)),
          ));
        }
      } else {
        final lines = parts[i].split('\n');
        final lang = lines.first.trim();
        final code = lines.skip(1).join('\n');
        if (code.isNotEmpty) widgets.add(CodeBlock(code: code, language: lang));
      }
    }

    if (isStreaming && !isThinking && mainText.trim().isNotEmpty) {
      widgets.add(const Padding(padding: EdgeInsets.only(top: 8), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }
}

class ThinkingAnimation extends StatefulWidget {
  const ThinkingAnimation({super.key});

  @override
  State<ThinkingAnimation> createState() => _ThinkingAnimationState();
}

class _ThinkingAnimationState extends State<ThinkingAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RotationTransition(
          turns: _controller,
          child: const Icon(Icons.autorenew, size: 18, color: Colors.deepPurpleAccent),
        ),
        const SizedBox(width: 8),
        const Text(
          'xdfaaa ai sedang berpikir...',
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.white54, fontSize: 13),
        ),
      ],
    );
  }
}
