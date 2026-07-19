import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/streams_provider.dart';
import 'providers/settings_provider.dart';
import 'services/domain_service.dart';
import 'utils/platform_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PlatformUtils.init();

  final domainService = await DomainService.getInstance();
  final settingsProvider = SettingsProvider();
  await settingsProvider.init();

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
