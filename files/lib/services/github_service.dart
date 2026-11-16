import 'dart:convert';

import 'package:http/http.dart' as http;

class GitHubService {
  /// Menerima "owner/repo" atau "https://github.com/owner/repo".
  static ({String owner, String repo}) parseRepoUrl(String url) {
    var u = url.trim().replaceAll(RegExp(r'/$'), '');
    if (u.endsWith('.git')) u = u.substring(0, u.length - 4);
    if (u.contains('github.com/')) {
      u = u.split('github.com/').last;
    }
    final parts = u.split('/');
    if (parts.length < 2 || parts[0].isEmpty || parts[1].isEmpty) {
      throw FormatException('URL repo tidak valid: $url');
    }
    return (owner: parts[0], repo: parts[1]);
  }

  static Map<String, String> _headers(String token) => {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'xdfaaa-ai-app',
      };

  static Future<bool> testConnection({
    required String token,
    required String repoUrl,
  }) async {
    try {
      final r = parseRepoUrl(repoUrl);
      final res = await http.get(
        Uri.parse('https://api.github.com/repos/${r.owner}/${r.repo}'),
        headers: _headers(token),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<void> uploadFile({
    required String token,
    required String repoUrl,
    required String path,
    required String content,
    String message = 'Update from xdfaaa ai',
  }) async {
    final r = parseRepoUrl(repoUrl);
    final url = Uri.parse(
        'https://api.github.com/repos/${r.owner}/${r.repo}/contents/$path');

    String? sha;
    final get = await http.get(url, headers: _headers(token));
    if (get.statusCode == 200) {
      sha = jsonDecode(get.body)['sha'] as String?;
    }

    final body = <String, dynamic>{
      'message': message,
      'content': base64.encode(utf8.encode(content)),
      if (sha != null) 'sha': sha,
    };
    final put = await http.put(
      url,
      headers: {..._headers(token), 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (put.statusCode != 200 && put.statusCode != 201) {
      throw Exception('Upload gagal: ${put.statusCode} ${put.body}');
    }
  }

  /// Backup seluruh riwayat chat ke repo di path backups/chat_<timestamp>.json
  static Future<String> backupChat({
    required String token,
    required String repoUrl,
    required String jsonContent,
  }) async {
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '')
        .substring(0, 15);
    final path = 'backups/chat_$ts.json';
    await uploadFile(
      token: token,
      repoUrl: repoUrl,
      path: path,
      content: jsonContent,
      message: 'Backup chat $ts',
    );
    return path;
  }
}
