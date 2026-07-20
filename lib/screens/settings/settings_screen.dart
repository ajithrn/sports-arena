import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../providers/settings_provider.dart';
import '../../providers/streams_provider.dart';
import '../../services/domain_service.dart';
import '../../services/update_service.dart';
import 'help_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _currentDomain;
  bool _isTestingConnection = false;
  String? _connectionStatus;

  @override
  void initState() {
    super.initState();
    _loadDomain();
  }

  Future<void> _loadDomain() async {
    final domainService = await DomainService.getInstance();
    setState(() {
      _currentDomain = domainService.domain;
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
    });

    try {
      final domainService = await DomainService.getInstance();
      final url =
          '${domainService.apiBaseUrl}${AppConfig.categoriesPath}';
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['categories'] != null) {
          setState(() => _connectionStatus = 'connected');
        } else {
          setState(() => _connectionStatus = 'invalid');
        }
      } else {
        setState(() => _connectionStatus = 'error');
      }
    } catch (e) {
      setState(() => _connectionStatus = 'error');
    } finally {
      setState(() => _isTestingConnection = false);
    }
  }

  Future<void> _changeServer() async {
    final controller = TextEditingController(text: _currentDomain ?? '');

    final newDomain = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the new streaming server domain.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Server domain',
                hintText: 'example.com',
                prefixIcon: const Icon(Icons.dns),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save & Test'),
          ),
        ],
      ),
    );

    if (newDomain == null || newDomain.trim().isEmpty) return;

    // Validate new domain
    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
    });

    try {
      String normalized = newDomain.trim();
      if (!normalized.startsWith('http://') &&
          !normalized.startsWith('https://')) {
        normalized = 'https://$normalized';
      }
      if (normalized.endsWith('/')) {
        normalized = normalized.substring(0, normalized.length - 1);
      }

      final testUrl =
          '$normalized${AppConfig.apiVersionPath}${AppConfig.categoriesPath}';
      final response = await http.get(Uri.parse(testUrl)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['categories'] != null && data['categories'] is List) {
          // Valid — save it
          final domainService = await DomainService.getInstance();
          await domainService.setDomain(normalized);

          setState(() {
            _currentDomain = normalized;
            _connectionStatus = 'connected';
          });

          // Refresh streams with new domain
          if (mounted) {
            context.read<StreamsProvider>().refresh();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Server updated successfully'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }

      setState(() => _connectionStatus = 'error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not connect to server'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _connectionStatus = 'error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isTestingConnection = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Server section
          _buildSectionHeader('Server'),
          _buildServerCard(),
          const SizedBox(height: 24),

          // Appearance section
          _buildSectionHeader('Appearance'),
          _buildThemeCard(settings),
          const SizedBox(height: 24),

          // Defaults section
          _buildSectionHeader('Defaults'),
          _buildDefaultsCard(settings),
          const SizedBox(height: 24),

          // Cache section
          _buildSectionHeader('Data & Cache'),
          _buildCacheCard(settings),
          const SizedBox(height: 24),

          // About section
          _buildSectionHeader('About'),
          _buildAboutCard(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildServerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.dns, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentDomain ?? 'Not configured',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                // Connection status icon
                if (_connectionStatus == 'connected')
                  const Icon(Icons.check_circle, color: Colors.green, size: 20)
                else if (_connectionStatus == 'error')
                  const Icon(Icons.error, color: Colors.red, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isTestingConnection ? null : _testConnection,
                  icon: _isTestingConnection
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_find, size: 18),
                  label: const Text('Test'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _changeServer,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Change'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCard(SettingsProvider settings) {
    return Card(
      child: RadioGroup<ThemeMode>(
        groupValue: settings.themeMode,
        onChanged: (mode) => settings.setThemeMode(mode!),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('Dark'),
              trailing: Radio<ThemeMode>(value: ThemeMode.dark),
              onTap: () => settings.setThemeMode(ThemeMode.dark),
            ),
            ListTile(
              leading: const Icon(Icons.light_mode),
              title: const Text('Light'),
              trailing: Radio<ThemeMode>(value: ThemeMode.light),
              onTap: () => settings.setThemeMode(ThemeMode.light),
            ),
            ListTile(
              leading: const Icon(Icons.settings_brightness),
              title: const Text('System'),
              trailing: Radio<ThemeMode>(value: ThemeMode.system),
              onTap: () => settings.setThemeMode(ThemeMode.system),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultsCard(SettingsProvider settings) {
    final categories = context.read<StreamsProvider>().categories;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Default category'),
            subtitle: Text(
              settings.defaultCategory ?? 'All (no filter)',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final selected = await showDialog<String?>(
                context: context,
                builder: (ctx) => SimpleDialog(
                  title: const Text('Default category'),
                  children: [
                    SimpleDialogOption(
                      child: const Text('All (no filter)'),
                      onPressed: () => Navigator.pop(ctx, ''),
                    ),
                    ...categories.map(
                      (c) => SimpleDialogOption(
                        child: Row(
                          children: [
                            Icon(c.icon, size: 20),
                            const SizedBox(width: 12),
                            Text(c.displayName),
                          ],
                        ),
                        onPressed: () => Navigator.pop(ctx, c.name),
                      ),
                    ),
                  ],
                ),
              );
              if (selected != null) {
                settings.setDefaultCategory(
                  selected.isEmpty ? null : selected,
                );
              }
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.autorenew),
            title: const Text('Auto-refresh streams'),
            subtitle: Text(
              'Every ${settings.refreshIntervalSeconds}s',
            ),
            value: settings.autoRefresh,
            onChanged: (v) => settings.setAutoRefresh(v),
          ),
          if (settings.autoRefresh)
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('Refresh interval'),
              trailing: DropdownButton<int>(
                value: settings.refreshIntervalSeconds,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 30, child: Text('30s')),
                  DropdownMenuItem(value: 60, child: Text('60s')),
                  DropdownMenuItem(value: 120, child: Text('2 min')),
                  DropdownMenuItem(value: 300, child: Text('5 min')),
                ],
                onChanged: (v) {
                  if (v != null) settings.setRefreshInterval(v);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCacheCard(SettingsProvider settings) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.cached),
            title: const Text('Clear stream cache'),
            subtitle: const Text('Force reload from server'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.read<StreamsProvider>().refresh();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Tips'),
            subtitle: const Text('How to use the app'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text(AppConfig.appName),
            subtitle: Text('Version ${AppConfig.appVersion}'),
          ),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('Check for updates'),
            subtitle: const Text('Download latest version from GitHub'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _checkForUpdate,
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdate() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final updateInfo = await UpdateService.checkForUpdate();

    if (!mounted) return;
    Navigator.pop(context); // dismiss loading

    if (updateInfo.hasUpdate) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Update Available'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New version: ${updateInfo.latestVersion}'),
              Text('Current: ${AppConfig.appVersion}'),
              if (updateInfo.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Release notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  updateInfo.releaseNotes,
                  maxLines: 10,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _openDownloadUrl(updateInfo.downloadUrl);
              },
              child: const Text('Download'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You\'re on the latest version!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openDownloadUrl(String url) async {
    if (url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No download URL available'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open: $url'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
