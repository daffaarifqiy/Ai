import 'package:flutter/material.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart' as llama;
import 'chat_screen.dart';
import 'project_screen.dart';

class RootScreen extends StatefulWidget {
  final llama.LlamaController controller;
  const RootScreen({super.key, required this.controller});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          ChatScreen(controller: widget.controller),
          const ProjectScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.folder_copy), label: 'Projects'),
        ],
      ),
    );
  }
}
