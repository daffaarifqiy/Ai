import 'package:flutter/material.dart';

import '../services/app_services.dart';
import 'chat_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  bool _checking = true;
  bool _permissionOk = false;
  bool _modelReady = false;
  bool _downloading = false;
  bool _loadingModel = false;
  double _progress = 0;
  String _status = 'Memeriksa izin...';

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    _permissionOk = await PermissionService.hasStorage();
    _modelReady = await ModelService.isModelDownloaded();
    setState(() {
      _checking = false;
      _status = _permissionOk
          ? (_modelReady ? 'Model siap' : 'Model belum diunduh')
          : 'Izin penyimpanan diperlukan';
    });
  }

  Future<void> _requestPermission() async {
    final ok = await PermissionService.requestStorage();
    if (!ok) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Izin ditolak'),
            content: const Text(
              'Aplikasi memerlukan akses penyimpanan untuk mengunduh model.',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal')),
              TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    PermissionService.openSettings();
                  },
                  child: const Text('Buka Pengaturan')),
            ],
          ),
        );
      }
      return;
    }
    setState(() => _permissionOk = true);
  }

  Future<void> _downloadAndLoad() async {
    if (!_modelReady) {
      setState(() {
        _downloading = true;
        _status = 'Mengunduh model...';
      });
      try {
        await ModelService.downloadModel(
          onProgress: (received, total) {
            setState(() {
              _progress = total > 0 ? received / total : 0;
              _status =
                  'Mengunduh ${(received / 1024 / 1024).toStringAsFixed(1)} MB'
                  ' / ${(total / 1024 / 1024).toStringAsFixed(1)} MB';
            });
          },
        );
        setState(() {
          _downloading = false;
          _modelReady = true;
        });
      } catch (e) {
        setState(() {
          _downloading = false;
          _status = 'Gagal mengunduh: $e';
        });
        return;
      }
    }
    setState(() {
      _loadingModel = true;
      _status = 'Memuat model ke memori...';
    });
    try {
      final c = await ModelService.loadModel();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ChatScreen(controller: c),
      ));
    } catch (e) {
      setState(() {
        _loadingModel = false;
        _status = 'Gagal memuat: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _checking
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipOval(
                      child: Image.asset(
                        'Meta_AI_hacker_logo_cutout_20261116_221322.png',
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.smart_toy,
                          size: 96,
                          color: Colors.deepPurpleAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('xdfaaa ai',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                      'Chat AI lokal · Qwen3-4B-abliterated',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60),
                    ),
                    const SizedBox(height: 32),
                    Text(_status, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    if (!_permissionOk)
                      FilledButton.icon(
                        onPressed: _requestPermission,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Izinkan Akses Penyimpanan'),
                      )
                    else if (!_modelReady && !_downloading)
                      FilledButton.icon(
                        onPressed: _downloadAndLoad,
                        icon: const Icon(Icons.download),
                        label: const Text('Unduh Model (2.5 GB)'),
                      )
                    else if (_downloading)
                      SizedBox(
                        width: 280,
                        child: Column(
                          children: [
                            LinearProgressIndicator(value: _progress),
                            const SizedBox(height: 8),
                            Text('${(_progress * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      )
                    else if (_loadingModel)
                      const CircularProgressIndicator()
                    else if (_modelReady)
                      FilledButton.icon(
                        onPressed: _downloadAndLoad,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Mulai Chat'),
                      ),
                    const SizedBox(height: 24),
                    const Text(
                      'Model & chat disimpan lokal di perangkat.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.white38),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
