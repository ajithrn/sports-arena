import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PlatformUtils {
  /// Whether we are running on the web
  static bool get isWeb => kIsWeb;

  /// Whether we are running on Android
  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Whether we are running on a desktop platform (macOS, Windows, Linux)
  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// Whether we are on Android TV (only true on Android after init)
  static bool isTv = false;

  /// Initialize platform detection (call once at startup)
  static Future<void> init() async {
    if (!isAndroid) {
      isTv = false;
      return;
    }

    try {
      const channel = MethodChannel('com.sportsarena/platform');
      final result = await channel.invokeMethod<bool>('isTv');
      isTv = result ?? false;
    } catch (e) {
      isTv = false;
    }
  }
}
