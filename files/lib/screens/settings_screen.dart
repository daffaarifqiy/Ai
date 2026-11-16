import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _pinCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _repoCtrl = TextEditingController();
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    // Ambil data yang sudah tersimpan sebelumnya
    final currentPin = await SettingsService.getPassword();
    final currentToken = await SettingsService.getGithubToken();
    final currentRepo = await SettingsService.getGithubRepo();

    if (mounted) {
      setState(() {
        _pinCtrl.text = currentPin;
        _tokenCtrl.text = currentToken;
        _repoCtrl.text = currentRepo;
        _isLoading = false;
      });
    }
  }

  Future<void> _savePin() async {
    final newPin = _pinCtrl.text.trim();
    if (newPin.length < 4) {
      _showSnackBar('PIN minimal 4 digit', isError: true);
      return;
    }
    await SettingsService.setPassword(newPin);
    _showSnackBar('PIN berhasil diperbarui');
  }

  Future<void> _saveGithub() async {
    await SettingsService.saveGithubConfig(
      token: _tokenCtrl.text.trim(),
      repoUrl: _repoCtrl.text.trim(),
    );
    _showSnackBar('Konfigurasi GitHub disimpan');
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _tokenCtrl.dispose();
    _repoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ==========================================
                // BAGIAN 1: KEAMANAN (PASSWORD)
                // ==========================================
                _buildSectionTitle('Keamanan Aplikasi', Icons.lock_outline),
                const SizedBox(height: 12),
                TextField(
                  controller: _pinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password PIN',
                    hintText: 'Masukkan PIN baru',
                    prefixIcon: Icon(Icons.password),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _savePin,
                    icon: const Icon(Icons.save),
                    label: const Text('Simpan PIN Baru'),
                  ),
                ),

                const SizedBox(height: 32),
                const Divider(color: Colors.white24),
                const SizedBox(height: 16),

                // ==========================================
                // BAGIAN 2: GITHUB (BACKUP)
                // ==========================================
                _buildSectionTitle('Backup ke GitHub', Icons.cloud_upload_outlined),
                const SizedBox(height: 8),
                const Text(
                  'Masukkan Personal Access Token (PAT) dan URL Repo GitHub kamu. '
                  'Data ini digunakan untuk mencadangkan riwayat chat secara otomatis.',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tokenCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'GitHub Token (PAT)',
                    hintText: 'ghp_xxxxxxxxxxxx',
                    prefixIcon: Icon(Icons.key),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _repoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL Repo GitHub',
                    hintText: 'https://github.com/username/repo',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _saveGithub,
                    icon: const Icon(Icons.cloud_done),
                    label: const Text('Simpan Konfigurasi GitHub'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepPurpleAccent,
                      side: const BorderSide(color: Colors.deepPurpleAccent),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                const Divider(color: Colors.white24),
                const SizedBox(height: 16),

                // ==========================================
                // BAGIAN 3: TENTANG APLIKASI
                // ==========================================
                _buildSectionTitle('Tentang', Icons.info_outline),
                const SizedBox(height: 12),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.smart_toy, color: Colors.deepPurpleAccent),
                  title: Text('xdfaaa ai'),
                  subtitle: Text('Versi 1.2.0\nModel: Qwen2.5-Coder-1.5B'),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.deepPurpleAccent),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
