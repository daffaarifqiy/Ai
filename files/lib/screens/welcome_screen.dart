import 'package:flutter/material.dart';
import '../services/app_services.dart';
import 'chat_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _checking = true;
  String _status = 'Memeriksa sistem...';

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      // Memberikan efek loading sebentar
      await Future.delayed(const Duration(seconds: 2));
      
      bool hasPerm = await PermissionService.hasStorage();
      if (!hasPerm) {
        setState(() => _status = 'Menunggu izin penyimpanan...');
        hasPerm = await PermissionService.requestStorage();
        if (!hasPerm) {
          setState(() => _status = 'Izin ditolak.\nBuka pengaturan dan izinkan akses penyimpanan.');
          return;
        }
      }

      setState(() => _status = 'Memuat AI...');
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

      setState(() => _status = 'Menyiapkan mesin AI...');
      
      // Jika library C++ crash, try-catch ini akan mencegah aplikasi tertutup
      final controller = await ModelService.loadModel();
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ChatScreen(controller: controller)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Gagal memuat AI:\n$e\n\nPastikan HP memiliki RAM yang cukup dan coba buka ulang aplikasi.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isError = _status.contains('Gagal') || _status.contains('ditolak');

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
              
              isError 
                  ? const Icon(Icons.error_outline, color: Colors.redAccent, size: 48)
                  : const CircularProgressIndicator(),
                  
              const SizedBox(height: 24),
              Text(_status, textAlign: TextAlign.center, style: TextStyle(color: isError ? Colors.redAccent : Colors.white54, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
