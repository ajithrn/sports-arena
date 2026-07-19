import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PlatformUtils {
  /// Whether we are running on the web
  static bool get isWeb => kIsWeb;

  /// Whether we are running on Android
  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Whether we are on Android TV
  static bool isTv = false;

  /// Initialize platform detection (call once at startup)
  static Future<void> init() async {
    if (isWeb) {
      isTv = false;
      return;
    }

    if (isAndroid) {
      try {
        // Use method channel to detect TV
        const channel = MethodChannel('com.sportsarena/platform');
        final result = await channel.invokeMethod<bool>('isTv');
        isTv = result ?? false;
      } catch (e) {
        // If method channel not available, detect by screen size heuristic
        isTv = false;
      }
    }
  }
}
