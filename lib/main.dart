import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'providers/streams_provider.dart';
import 'providers/settings_provider.dart';
import 'services/dns_bypass_service.dart';
import 'services/domain_service.dart';
import 'utils/platform_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PlatformUtils.init();

  // Load settings first
  final settingsProvider = SettingsProvider();
  await settingsProvider.init();

  // Start DNS bypass service on native platforms.
  // This runs a local CONNECT proxy that resolves domains via DoH,
  // bypassing ISP DNS poisoning. All Dart HTTP traffic is routed through it.
  if (!kIsWeb) {
    final bypass = DnsBypassService();
    bypass.setDohServer(settingsProvider.dohServer);
    if (settingsProvider.proxyEnabled) {
      await bypass.start();
      HttpOverrides.global = DnsBypassHttpOverrides();

      // On Android, configure WebView to use our proxy
      // so the embed player's network requests go through DoH resolution
      if (PlatformUtils.isAndroid && bypass.isRunning) {
        const platform = MethodChannel('com.sportsarena/platform');
        try {
          await platform.invokeMethod('setWebViewProxy', {
            'host': 'localhost',
            'port': bypass.port,
          });
        } catch (e) {
          debugPrint('Failed to set WebView proxy: $e');
        }
      }

      // On macOS, set system proxy so WKWebView routes through our proxy
      if (PlatformUtils.isDesktop &&
          defaultTargetPlatform == TargetPlatform.macOS &&
          bypass.isRunning) {
        const platform = MethodChannel('com.sportsarena/platform');
        try {
          final success = await platform.invokeMethod<bool>('setSystemProxy', {
            'host': '127.0.0.1',
            'port': bypass.port,
          });
          if (success == true) {
            debugPrint('macOS system proxy set to 127.0.0.1:${bypass.port}');
          } else {
            debugPrint('macOS system proxy NOT set — WKWebView will not use DNS bypass. '
                'User may need to grant admin privileges or set manually: '
                'networksetup -setsecurewebproxy Wi-Fi 127.0.0.1 ${bypass.port}');
          }
        } catch (e) {
          debugPrint('Failed to set system proxy: $e — '
              'WKWebView player will not bypass ISP blocking');
        }
      }

      // On Windows, set user-level Internet proxy so WebView2 routes through
      // our CONNECT proxy for DoH-based DNS resolution.
      // WebView2 (Edge) uses WinINET proxy settings from the registry.
      // This does NOT require admin privileges.
      if (PlatformUtils.isDesktop &&
          defaultTargetPlatform == TargetPlatform.windows &&
          bypass.isRunning) {
        try {
          // Enable proxy and set proxy server in user's Internet Settings
          await Process.run('reg', [
            'add',
            r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
            '/v', 'ProxyEnable',
            '/t', 'REG_DWORD',
            '/d', '1',
            '/f',
          ]);
          await Process.run('reg', [
            'add',
            r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
            '/v', 'ProxyServer',
            '/t', 'REG_SZ',
            '/d', '127.0.0.1:${bypass.port}',
            '/f',
          ]);
          debugPrint('Windows user proxy set to 127.0.0.1:${bypass.port}');
        } catch (e) {
          debugPrint('Failed to set Windows proxy: $e — '
              'WebView2 player will not bypass ISP DNS blocking');
        }
      }
    }
  }

  // On Windows, ensure the user proxy is cleared when the app exits.
  // Without this, the system proxy would remain set after the app closes,
  // breaking normal browsing until the user manually disables it.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    AppLifecycleListener(onExitRequested: () async {
      await DnsBypassService().stop();
      return AppExitResponse.exit;
    });
  }

  // Initialize window_manager for desktop platforms
  if (PlatformUtils.isDesktop) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1100, 750),
      minimumSize: Size(800, 600),
      center: true,
      title: 'Sports Arena',
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final domainService = await DomainService.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => StreamsProvider(domainService),
        ),
        ChangeNotifierProvider.value(value: settingsProvider),
      ],
      child: const SportsArenaApp(),
    ),
  );
}
