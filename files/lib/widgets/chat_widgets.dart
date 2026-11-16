import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

// Layar WebView untuk menjalankan HTML
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
  const MessageBubble({super.key, required this.message, this.isStreaming = false});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.transparent,
              child: ClipOval(child: Image.asset('assets/Meta_AI_hacker_logo_cutout_20261116_221322.png', width: 32, height: 32, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.smart_toy))),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: message.content));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pesan disalin')));
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isUser ? const Color(0xFF7C4DFF).withOpacity(0.25) : const Color(0xFF21262D),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  border: Border.all(color: isUser ? const Color(0xFF7C4DFF).withOpacity(0.5) : Colors.white12),
                ),
                child: isUser
                    ? SelectableText(message.content, style: const TextStyle(fontSize: 15, height: 1.4))
                    : _AssistantContent(content: message.content, isStreaming: isStreaming),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantContent extends StatelessWidget {
  final String content;
  final bool isStreaming;
  const _AssistantContent({required this.content, required this.isStreaming});

  @override
  Widget build(BuildContext context) {
    final parts = content.split('```');
    final widgets = <Widget>[];
    for (int i = 0; i < parts.length; i++) {
      if (i.isEven) {
        final t = parts[i];
        if (t.trim().isNotEmpty) widgets.add(SelectableText(t, style: const TextStyle(fontSize: 15, height: 1.4)));
      } else {
        final lines = parts[i].split('\n');
        final lang = lines.first.trim();
        final code = lines.skip(1).join('\n');
        if (code.isNotEmpty) widgets.add(CodeBlock(code: code, language: lang));
      }
    }
    if (isStreaming) {
      widgets.add(const Padding(padding: EdgeInsets.only(top: 8), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }
}
