import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service to download and install APK updates on Android.
class ApkDownloadService {
  static final Dio _dio = Dio();
  static CancelToken? _cancelToken;

  /// Downloads an APK from [url] and triggers installation.
  ///
  /// [onProgress] reports download progress as a value between 0.0 and 1.0.
  /// [onStatusChange] reports status messages.
  /// Returns true if the install was triggered successfully.
  static Future<bool> downloadAndInstall({
    required String url,
    required void Function(double progress) onProgress,
    required void Function(String status) onStatusChange,
  }) async {
    try {
      // Step 1: Request install-from-unknown-sources permission
      final hasPermission = await _requestInstallPermission(onStatusChange);
      if (!hasPermission) {
        onStatusChange('Install permission denied. Please allow "Install unknown apps" for Sports Arena in Settings.');
        return false;
      }

      onStatusChange('Starting download...');

      // Step 2: Get a download directory accessible to the package installer
      final dir = await _getDownloadDirectory();
      final filePath = '${dir.path}/sports_arena_update.apk';

      // Delete old APK if it exists
      final oldFile = File(filePath);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }

      // Step 3: Download the APK
      _cancelToken = CancelToken();
      await _dio.download(
        url,
        filePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            onProgress(progress);
            final mb = (received / 1024 / 1024).toStringAsFixed(1);
            final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
            onStatusChange('Downloading... $mb / $totalMb MB');
          }
        },
      );

      onProgress(1.0);
      onStatusChange('Download complete. Opening installer...');

      // Step 4: Trigger APK installation via open_filex
      // open_filex handles FileProvider content URI creation internally
      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type == ResultType.done) {
        onStatusChange('Installation started');
        return true;
      } else if (result.type == ResultType.permissionDenied) {
        // This means the app doesn't have permission to install packages
        // Guide user to enable it manually
        onStatusChange('Permission denied. Go to Settings > Apps > Sports Arena > Install unknown apps and enable it.');
        // Try to open app settings so user can grant permission
        await openAppSettings();
        return false;
      } else {
        onStatusChange('Could not open installer: ${result.message}');
        return false;
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        onStatusChange('Download cancelled');
      } else {
        onStatusChange('Download failed. Check your connection.');
      }
      return false;
    } catch (e) {
      debugPrint('APK install error: $e');
      onStatusChange('Update failed. Try downloading from the browser instead.');
      return false;
    }
  }

  /// Cancel an ongoing download.
  static void cancelDownload() {
    _cancelToken?.cancel('User cancelled');
    _cancelToken = null;
  }

  /// Request permission to install from unknown sources (Android 8+).
  /// On older versions, this is a global toggle and doesn't need per-app permission.
  static Future<bool> _requestInstallPermission(
    void Function(String status) onStatusChange,
  ) async {
    if (!Platform.isAndroid) return true;

    // Check current status
    var status = await Permission.requestInstallPackages.status;

    if (status.isGranted) return true;

    // Request the permission - this opens the system settings page
    // on Android 8+ where user must manually toggle "Allow from this source"
    onStatusChange('Requesting install permission...');
    status = await Permission.requestInstallPackages.request();

    if (status.isGranted) return true;

    // If permanently denied, direct user to app settings
    if (status.isPermanentlyDenied) {
      onStatusChange('Opening settings to grant install permission...');
      await openAppSettings();
      // Re-check after user returns
      await Future.delayed(const Duration(seconds: 2));
      status = await Permission.requestInstallPackages.status;
      return status.isGranted;
    }

    return false;
  }

  /// Get a suitable directory for downloading the APK.
  /// Uses external cache which is accessible by the package installer
  /// via FileProvider without needing storage permissions.
  static Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      // Prefer external cache - accessible via FileProvider and doesn't
      // require storage permissions on any Android version
      final externalDirs = await getExternalCacheDirectories();
      if (externalDirs != null && externalDirs.isNotEmpty) {
        return externalDirs.first;
      }

      // Fallback to app's external storage directory
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) return externalDir;
    }

    // Last resort fallback
    return await getTemporaryDirectory();
  }
}
