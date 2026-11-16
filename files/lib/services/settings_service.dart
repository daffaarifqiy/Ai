import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _kToken = 'github_token';
  static const _kRepo = 'github_repo_url';

  static Future<void> saveGitHub({
    required String token,
    required String repoUrl,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, token.trim());
    await p.setString(_kRepo, repoUrl.trim());
  }

  static Future<String> getToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kToken) ?? '';
  }

  static Future<String> getRepoUrl() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kRepo) ?? '';
  }

  static Future<bool> hasGitHubConfig() async {
    final t = await getToken();
    final r = await getRepoUrl();
    return t.isNotEmpty && r.isNotEmpty;
  }
}
