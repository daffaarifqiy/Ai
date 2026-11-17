import 'package:flutter/material.dart';
import '../services/app_services.dart';
import 'chat_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String _status = 'Siap memulai.';
  bool _isLoading = false;

  Future<void> _startAI() async {
    setState(() {
      _isLoading = true;
      _status = 'Memeriksa izin...';
    });

    try {
      bool hasPerm = await PermissionService.hasStorage();
      if (!hasPerm) {
        hasPerm = await PermissionService.requestStorage();
        if (!hasPerm) {
          setState(() {
            _isLoading = false;
            _status = 'Izin ditolak. Buka pengaturan HP dan izinkan akses penyimpanan.';
          });
          return;
        }
      }

      setState(() => _status = 'Memeriksa model...');
      bool modelReady = await ModelService.isModelDownloaded();

      if (!modelReady) {
        setState(() => _status = 'Mengunduh model (1.1 GB)...');
        await ModelService.downloadModel(onProgress: (recv, total) {
          if (mounted && total > 0) {
            setState(() {
              _status = 'Mengunduh: ${(recv / 1024 / 1024).toStringAsFixed(0)} MB / ${(total / 1024 / 1024).toStringAsFixed(0)} MB';
            });
          }
        });
      }

      setState(() => _status = 'Memuat mesin AI...');
      
      // Proses ini memuat library C++ (llama.cpp)
      final controller = await ModelService.loadModel();
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ChatScreen(controller: controller)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _status = 'Gagal memuat AI:\n$e\n\nPastikan HP memiliki RAM yang cukup.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/ai.jpg.png', 
                  width: 100, height: 100, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.psychology, size: 100, color: Colors.deepPurpleAccent),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Selamat datang,', style: TextStyle(fontSize: 18, color: Colors.white70)),
              const SizedBox(height: 8),
              const Text('Athailla Daffa Arifqiy', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 48),
              
              if (_isLoading) 
                const CircularProgressIndicator()
              else
                FilledButton.icon(
                  onPressed: _startAI,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Mulai AI'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              
              const SizedBox(height: 24),
              Text(
                _status, 
                textAlign: TextAlign.center, 
                style: TextStyle(
                  color: _status.contains('Gagal') || _status.contains('ditolak') ? Colors.redAccent : Colors.white54, 
                  fontSize: 14
                )
              ),
            ],
          ),
        ),
      ),
    );
  }
}
