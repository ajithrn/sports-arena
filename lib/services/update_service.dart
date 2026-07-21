import 'dart:convert';
import 'package:flutter/foundation.dart';
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

        // Find the correct download URL based on platform
        String downloadUrl = data['html_url'] ?? '';
        final assets = data['assets'] as List? ?? [];
        downloadUrl = _findPlatformAsset(assets, downloadUrl);

        final hasUpdate = _isNewerVersion(latestVersion, AppConfig.appVersion);

        // Fetch the commit message for the release tag
        String releaseNotes = '';
        if (hasUpdate) {
          releaseNotes = await _getTagCommitMessage(latestVersion);
        }

        return UpdateInfo(
          latestVersion: latestVersion,
          downloadUrl: downloadUrl,
          releaseNotes: releaseNotes,
          hasUpdate: hasUpdate,
        );
      }

      return _noUpdate();
    } catch (e) {
      return _noUpdate();
    }
  }

  static UpdateInfo _noUpdate() => UpdateInfo(
        latestVersion: AppConfig.appVersion,
        downloadUrl: '',
        releaseNotes: '',
        hasUpdate: false,
      );

  /// Get the commit message for a release tag
  static Future<String> _getTagCommitMessage(String version) async {
    try {
      final url = '${AppConfig.githubApiUrl}/git/refs/tags/v$version';
      final res = await http.get(Uri.parse(url), headers: {
        'Accept': 'application/vnd.github.v3+json',
      }).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return '';

      final sha = json.decode(res.body)['object']?['sha'] as String? ?? '';
      if (sha.isEmpty) return '';

      final commitRes = await http.get(
        Uri.parse('${AppConfig.githubApiUrl}/commits/$sha'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 5));
      if (commitRes.statusCode != 200) return '';

      return json.decode(commitRes.body)['commit']?['message'] as String? ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Find the correct asset download URL for the current platform
  static String _findPlatformAsset(List assets, String fallbackUrl) {
    if (kIsWeb) return fallbackUrl;

    final suffix = switch (defaultTargetPlatform) {
      TargetPlatform.android => '.apk',
      TargetPlatform.macOS => '-macos.dmg',
      TargetPlatform.windows => '-windows.zip',
      TargetPlatform.linux => '-linux',
      _ => '',
    };

    if (suffix.isEmpty) return fallbackUrl;

    for (final asset in assets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.endsWith(suffix)) {
        return asset['browser_download_url'] ?? fallbackUrl;
      }
    }

    return fallbackUrl;
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
