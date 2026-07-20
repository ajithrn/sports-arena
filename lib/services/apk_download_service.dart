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
  /// [onStatusChange] reports status messages (e.g. "Downloading...", "Installing...").
  /// Returns true if the install was triggered successfully.
  static Future<bool> downloadAndInstall({
    required String url,
    required void Function(double progress) onProgress,
    required void Function(String status) onStatusChange,
  }) async {
    try {
      // Request necessary permissions
      final hasPermission = await _requestPermissions();
      if (!hasPermission) {
        onStatusChange('Permission denied');
        return false;
      }

      onStatusChange('Starting download...');

      // Get download directory
      final dir = await _getDownloadDirectory();
      final filePath = '${dir.path}/sports_arena_update.apk';

      // Delete old APK if it exists
      final oldFile = File(filePath);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }

      // Download the APK
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
      onStatusChange('Download complete. Installing...');

      // Trigger APK installation
      final result = await OpenFilex.open(filePath, type: 'application/vnd.android.package-archive');

      if (result.type == ResultType.done) {
        onStatusChange('Installation started');
        return true;
      } else {
        onStatusChange('Could not open APK: ${result.message}');
        return false;
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        onStatusChange('Download cancelled');
      } else {
        onStatusChange('Download failed: ${e.message}');
      }
      return false;
    } catch (e) {
      onStatusChange('Error: $e');
      return false;
    }
  }

  /// Cancel an ongoing download.
  static void cancelDownload() {
    _cancelToken?.cancel('User cancelled');
    _cancelToken = null;
  }

  /// Request storage and install permissions.
  static Future<bool> _requestPermissions() async {
    // On Android 8+, we need REQUEST_INSTALL_PACKAGES (declared in manifest,
    // but user must grant it). Check and request it.
    if (Platform.isAndroid) {
      // Request install packages permission
      final installStatus = await Permission.requestInstallPackages.request();
      if (!installStatus.isGranted) {
        debugPrint('Install packages permission denied');
        return false;
      }

      // For Android < 10, request storage permission
      if (await _needsStoragePermission()) {
        final storageStatus = await Permission.storage.request();
        if (!storageStatus.isGranted) {
          debugPrint('Storage permission denied');
          return false;
        }
      }
    }

    return true;
  }

  /// Check if we need explicit storage permission (Android 9 and below).
  static Future<bool> _needsStoragePermission() async {
    // On Android 10+ (API 29+), we use app-specific directories and don't need
    // WRITE_EXTERNAL_STORAGE. On older versions, we do.
    // The permission_handler library handles this gracefully.
    final status = await Permission.storage.status;
    return !status.isGranted && !status.isRestricted;
  }

  /// Get a suitable directory for downloading the APK.
  static Future<Directory> _getDownloadDirectory() async {
    // Use external cache directory on Android - it doesn't require permissions
    // on Android 10+ and is accessible by the package installer.
    if (Platform.isAndroid) {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        return externalDir;
      }
    }
    // Fallback to temporary directory
    return await getTemporaryDirectory();
  }
}
