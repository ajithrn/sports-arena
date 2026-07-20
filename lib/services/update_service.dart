import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class UpdateInfo {
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool hasUpdate;

  UpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.hasUpdate,
  });
}

class UpdateService {
  /// Check GitHub Releases for a newer version
  static Future<UpdateInfo> checkForUpdate() async {
    try {
      final url = '${AppConfig.githubApiUrl}/releases/latest';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tagName = data['tag_name'] as String? ?? '';
        final latestVersion = tagName.replaceFirst('v', '');
        final body = data['body'] as String? ?? '';

        // Find the APK download URL from assets
        String downloadUrl = data['html_url'] ?? '';
        final assets = data['assets'] as List? ?? [];
        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (name.endsWith('.apk')) {
            downloadUrl = asset['browser_download_url'] ?? downloadUrl;
            break;
          }
        }

        final hasUpdate = _isNewerVersion(latestVersion, AppConfig.appVersion);

        return UpdateInfo(
          latestVersion: latestVersion,
          downloadUrl: downloadUrl,
          releaseNotes: body,
          hasUpdate: hasUpdate,
        );
      }

      return UpdateInfo(
        latestVersion: AppConfig.appVersion,
        downloadUrl: '',
        releaseNotes: '',
        hasUpdate: false,
      );
    } catch (e) {
      return UpdateInfo(
        latestVersion: AppConfig.appVersion,
        downloadUrl: '',
        releaseNotes: '',
        hasUpdate: false,
      );
    }
  }

  /// Compare version strings (e.g., "1.2.0" > "1.1.0")
  static bool _isNewerVersion(String latest, String current) {
    final latestParts = latest.split('.').map(int.tryParse).toList();
    final currentParts = current.split('.').map(int.tryParse).toList();

    for (int i = 0; i < 3; i++) {
      final l = (i < latestParts.length ? latestParts[i] : 0) ?? 0;
      final c = (i < currentParts.length ? currentParts[i] : 0) ?? 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }
}
