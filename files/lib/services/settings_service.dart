import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  // Kunci untuk SharedPreferences
  static const String _keyPassword = 'app_password';
  static const String _keyGithubToken = 'github_token';
  static const String _keyGithubRepo = 'github_repo_url';

  // ==========================================
  // 1. PENGATURAN PASSWORD (PIN)
  // ==========================================

  /// Mengambil password PIN (Default: '040412' jika belum pernah diganti)
  static Future<String> getPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPassword) ?? '040412';
  }

  /// Menyimpan password PIN baru
  static Future<void> setPassword(String newPassword) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPassword, newPassword.trim());
  }

  // ==========================================
  // 2. PENGATURAN GITHUB (UNTUK BACKUP)
  // ==========================================

  /// Mengambil GitHub Personal Access Token
  static Future<String> getGithubToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGithubToken) ?? '';
  }

  /// Mengambil URL Repo GitHub (misal: https://github.com/user/repo)
  static Future<String> getGithubRepo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGithubRepo) ?? '';
  }

  /// Menyimpan Token dan URL Repo GitHub
  static Future<void> saveGithubConfig({
    required String token,
    required String repoUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyGithubToken, token.trim());
    await prefs.setString(_keyGithubRepo, repoUrl.trim());
  }

  /// Cek apakah user sudah mengisi konfigurasi GitHub
  static Future<bool> hasGithubConfig() async {
    final token = await getGithubToken();
    final repo = await getGithubRepo();
    return token.isNotEmpty && repo.isNotEmpty;
  }

  // ==========================================
  // 3. RESET PENGATURAN (OPSIONAL)
  // ==========================================
  
  /// Menghapus semua pengaturan dan mengembalikan ke default
  static Future<void> resetAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPassword);
    await prefs.remove(_keyGithubToken);
    await prefs.remove(_keyGithubRepo);
  }
}
