import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../providers/settings_provider.dart';
import '../../providers/streams_provider.dart';
import '../../services/dns_bypass_service.dart';
import '../../services/domain_service.dart';
import '../../services/update_service.dart';
import '../../services/apk_download_service.dart';
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
    final screenWidth = MediaQuery.of(context).size.width;
    final useWideLayout = screenWidth > 700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        scrolledUnderElevation: 0,
      ),
      body: useWideLayout
          ? _buildWideLayout(settings)
          : _buildNarrowLayout(settings),
    );
  }

  Widget _buildNarrowLayout(SettingsProvider settings) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Server'),
        _buildServerCard(),
        const SizedBox(height: 20),
        _buildSectionHeader('Appearance'),
        _buildThemeCard(settings),
        const SizedBox(height: 20),
        _buildSectionHeader('Defaults'),
        _buildDefaultsCard(settings),
        const SizedBox(height: 20),
        _buildSectionHeader('Data & Cache'),
        _buildCacheCard(settings),
        const SizedBox(height: 20),
        _buildSectionHeader('Network'),
        _buildProxyCard(settings),
        const SizedBox(height: 20),
        _buildSectionHeader('About'),
        _buildAboutCard(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildWideLayout(SettingsProvider settings) {
    const columns = 2;

    // Group sections into rows for consistent heights
    final sections = [
      _buildSectionWithHeader('Server', _buildServerCard()),
      _buildSectionWithHeader('Appearance', _buildThemeCard(settings)),
      _buildSectionWithHeader('Network', _buildProxyCard(settings)),
      _buildSectionWithHeader('Defaults', _buildDefaultsCard(settings)),
      _buildSectionWithHeader('Data & Cache', _buildCacheCard(settings)),
      _buildSectionWithHeader('About', _buildAboutCard()),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {

        // Split sections into rows of 2
        final rows = <List<Widget>>[];
        for (int i = 0; i < sections.length; i += columns) {
          rows.add(sections.sublist(i, (i + columns).clamp(0, sections.length)));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: rows.map((row) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < row.length; i++) ...[
                        if (i > 0) const SizedBox(width: 16),
                        Expanded(child: row[i]),
                      ],
                      // Fill remaining space if row is incomplete
                      if (row.length < columns) ...[
                        const SizedBox(width: 16),
                        const Expanded(child: SizedBox()),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSectionWithHeader(String title, Widget card) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        Expanded(child: card),
      ],
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
          ListTile(
            leading: const Icon(Icons.high_quality_outlined),
            title: const Text('Default quality'),
            subtitle: Text(settings.preferredQualityName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showQualityPicker(settings),
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

  Widget _buildProxyCard(SettingsProvider settings) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.shield_outlined),
            title: const Text('DNS Proxy'),
            subtitle: Text(
              settings.proxyEnabled
                  ? 'Bypasses ISP DNS blocking'
                  : 'Using system DNS',
            ),
            value: settings.proxyEnabled,
            onChanged: (value) async {
              await settings.setProxyEnabled(value);
              await DnsBypassService().setEnabled(value);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(value
                        ? 'DNS proxy enabled. Restart app for full effect.'
                        : 'DNS proxy disabled. Restart app for full effect.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          if (settings.proxyEnabled)
            ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: const Text('DNS Server'),
              subtitle: Text(settings.dohServerName),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDnsServerPicker(settings),
            ),
        ],
      ),
    );
  }

  void _showDnsServerPicker(SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('DNS Server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SettingsProvider.dohServers.entries.map((entry) {
            final isSelected = entry.value == settings.dohServer;
            return ListTile(
              title: Text(entry.key),
              subtitle: Text(entry.value, style: const TextStyle(fontSize: 12)),
              leading: Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? Theme.of(ctx).colorScheme.primary : null,
              ),
              onTap: () {
                settings.setDohServer(entry.value);
                DnsBypassService().setDohServer(entry.value);
                DnsBypassService().clearCache();
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showQualityPicker(SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Default quality'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SettingsProvider.qualityOptions.entries.map((entry) {
            final isSelected = entry.value == settings.preferredQuality;
            return ListTile(
              title: Text(entry.key),
              leading: Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? Theme.of(ctx).colorScheme.primary : null,
              ),
              onTap: () {
                settings.setPreferredQuality(entry.value);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
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
        builder: (ctx) => _UpdateDialog(
          updateInfo: updateInfo,
          onDownload: () {
            Navigator.pop(ctx);
            _openDownloadUrl(updateInfo.downloadUrl);
          },
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

    // On Android, download and install APK in-app
    if (!kIsWeb && Platform.isAndroid) {
      _downloadAndInstallApk(url);
      return;
    }

    // On other platforms, open in browser
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

  void _downloadAndInstallApk(String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DownloadProgressDialog(
        url: url,
        onDone: (success, status) {
          if (!success && status != 'Download cancelled') {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text(status),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Update Available Dialog
// ──────────────────────────────────────────────

class _UpdateDialog extends StatelessWidget {
  final UpdateInfo updateInfo;
  final VoidCallback onDownload;

  const _UpdateDialog({required this.updateInfo, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.system_update,
                      color: theme.colorScheme.onPrimaryContainer,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update Available',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'v${AppConfig.appVersion} → v${updateInfo.latestVersion}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Release notes (commit message)
              if (updateInfo.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  "What's new",
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      updateInfo.releaseNotes,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],

              // Actions
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Later'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Update'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Download Progress Dialog
// ──────────────────────────────────────────────

class _DownloadProgressDialog extends StatefulWidget {
  final String url;
  final void Function(bool success, String status) onDone;

  const _DownloadProgressDialog({required this.url, required this.onDone});

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0;
  String _status = 'Preparing download...';
  bool _started = false;
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  void _startDownload() {
    if (_started) return;
    _started = true;

    ApkDownloadService.downloadAndInstall(
      url: widget.url,
      onProgress: (p) {
        if (!_isCancelled && mounted) {
          setState(() => _progress = p);
        }
      },
      onStatusChange: (s) {
        if (!_isCancelled && mounted) {
          setState(() => _status = s);
        }
      },
    ).then((success) {
      if (!_isCancelled && mounted) {
        Navigator.of(context).pop();
        widget.onDone(success, _status);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (_progress * 100).toInt();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress indicator
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    strokeWidth: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  if (_progress > 0)
                    Text(
                      '$percent%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Text(
              _progress >= 1.0 ? 'Installing...' : 'Downloading Update',
              style: theme.textTheme.titleMedium,
            ),

            const SizedBox(height: 8),

            Text(
              _status,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            // Cancel button
            if (_progress < 1.0)
              TextButton(
                onPressed: () {
                  _isCancelled = true;
                  ApkDownloadService.cancelDownload();
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
          ],
        ),
      ),
    );
  }
}
