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
    // Memberikan efek loading sebentar agar ucapan selamat datang terlihat
    await Future.delayed(const Duration(seconds: 2));
    
    bool hasPerm = await PermissionService.hasStorage();
    if (!hasPerm) {
      setState(() => _status = 'Menunggu izin penyimpanan...');
      hasPerm = await PermissionService.requestStorage();
      if (!hasPerm) {
        setState(() => _status = 'Izin ditolak. Aplikasi tidak bisa berjalan.');
        return;
      }
    }

    setState(() => _status = 'Memuat AI...');
    bool modelReady = await ModelService.isModelDownloaded();

    if (!modelReady) {
      setState(() => _status = 'Mengunduh model (1.1 GB)...');
      try {
        await ModelService.downloadModel(onProgress: (recv, total) {
          if (mounted) {
            setState(() {
              _status = 'Mengunduh: ${(recv / 1024 / 1024).toStringAsFixed(0)} MB / ${(total / 1024 / 1024).toStringAsFixed(0)} MB';
            });
          }
        });
      } catch (e) {
        setState(() => _status = 'Gagal unduh model: $e');
        return;
      }
    }

    setState(() => _status = 'Menyiapkan mesin AI...');
    try {
      final controller = await ModelService.loadModel();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ChatScreen(controller: controller)),
        );
      }
    } catch (e) {
      setState(() => _status = 'Gagal memuat model: $e');
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
                  'assets/Meta_AI_hacker_logo_cutout_20261116_221322.png',
                  width: 100, height: 100, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.psychology, size: 100, color: Colors.deepPurpleAccent),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Selamat datang,',
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              const Text(
                'Athailla Daffa Arifqiy',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
