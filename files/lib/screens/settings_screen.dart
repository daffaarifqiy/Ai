import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../services/github_service.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _tokenCtrl = TextEditingController();
  final _repoCtrl = TextEditingController();
  bool _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _tokenCtrl.text = await SettingsService.getToken();
    _repoCtrl.text = await SettingsService.getRepoUrl();
    setState(() {});
  }

  Future<void> _save() async {
    await SettingsService.saveGitHub(
      token: _tokenCtrl.text,
      repoUrl: _repoCtrl.text,
    );
    setState(() => _status = 'Disimpan');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengaturan GitHub disimpan')),
      );
    }
  }

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _status = 'Menguji koneksi...';
    });
    final ok = await GitHubService.testConnection(
      token: _tokenCtrl.text.trim(),
      repoUrl: _repoCtrl.text.trim(),
    );
    setState(() {
      _busy = false;
      _status = ok ? 'Koneksi berhasil ✓' : 'Koneksi gagal ✗';
    });
  }

  Future<void> _backup() async {
    final token = _tokenCtrl.text.trim();
    final repo = _repoCtrl.text.trim();
    if (token.isEmpty || repo.isEmpty) {
      setState(() => _status = 'Isi token & repo dulu');
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Mengunggah backup...';
    });
    try {
      final data = ChatStorage.loadAll().map((m) => m.toMap()).toList();
      final json = const JsonEncoder.withIndent('  ').convert({
        'app': 'xdfaaa ai',
        'exported_at': DateTime.now().toIso8601String(),
        'messages': data,
      });
      final path = await GitHubService.backupChat(
        token: token,
        repoUrl: repo,
        jsonContent: json,
      );
      setState(() {
        _busy = false;
        _status = 'Backup tersimpan di $path';
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _status = 'Gagal backup: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('GitHub (untuk backup chat)',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _tokenCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'GitHub Token (Personal Access Token)',
              hintText: 'ghp_...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _repoCtrl,
            decoration: const InputDecoration(
              labelText: 'Link Repo GitHub',
              hintText: 'https://github.com/username/xdfaaa-ai',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Simpan'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _test,
                  icon: const Icon(Icons.wifi_tethering),
                  label: const Text('Test'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _backup,
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Backup Chat ke GitHub'),
          ),
          if (_status != null) ...[
            const SizedBox(height: 16),
            Text(_status!,
                style: const TextStyle(color: Colors.white70)),
          ],
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          const SizedBox(height: 32),
          const Text(
            'Token disimpan lokal di perangkat (SharedPreferences). '
            'Backup chat akan membuat file di folder backups/ pada repo.',
            style: TextStyle(fontSize: 12, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}
