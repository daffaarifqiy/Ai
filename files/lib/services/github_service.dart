import 'dart:convert';
import 'package:http/http.dart' as http;

class GitHubService {
  static ({String owner, String repo}) parseRepoUrl(String url) {
    var u = url.trim().replaceAll(RegExp(r'/$'), '');
    if (u.endsWith('.git')) u = u.substring(0, u.length - 4);
    if (u.contains('github.com/')) u = u.split('github.com/').last;
    final parts = u.split('/');
    if (parts.length < 2) throw Exception('URL Repo tidak valid');
    return (owner: parts[0], repo: parts[1]);
  }

  static Map<String, String> _headers(String token) => {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'xdfaaa-ai-app',
      };

  static Future<void> uploadBase64File({
    required String token,
    required String repoUrl,
    required String path,
    required String base64Content,
    String message = 'Upload from xdfaaa ai',
  }) async {
    final r = parseRepoUrl(repoUrl);
    final url = Uri.parse('https://api.github.com/repos/${r.owner}/${r.repo}/contents/$path');

    String? sha;
    final get = await http.get(url, headers: _headers(token));
    
    // Cek jika repo tidak ditemukan atau private
    if (get.statusCode == 404) {
      throw Exception('Repo tidak ditemukan. Pastikan URL benar dan Repo bersifat PUBLIK.');
    } else if (get.statusCode == 401) {
      throw Exception('Token GitHub tidak valid atau kedaluwarsa.');
    }

    if (get.statusCode == 200) {
      sha = jsonDecode(get.body)['sha'] as String?;
    }

    final body = <String, dynamic>{
      'message': message,
      'content': base64Content,
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
}
