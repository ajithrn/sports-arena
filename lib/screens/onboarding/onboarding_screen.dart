import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../services/domain_service.dart';
import '../../utils/platform_utils.dart';
import '../home/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _domainController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isValidating = false;
  String? _errorMessage;
  String? _pendingDomain;

  @override
  void dispose() {
    _domainController.dispose();
    super.dispose();
  }

  Future<void> _handleConnect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    final domain = _domainController.text.trim();

    try {
      // Normalize the domain
      String normalized = domain;
      if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
        normalized = 'https://$normalized';
      }
      if (normalized.endsWith('/')) {
        normalized = normalized.substring(0, normalized.length - 1);
      }

      // Test the connection by hitting the categories endpoint
      final testUrl = '$normalized${AppConfig.apiVersionPath}${AppConfig.categoriesPath}';
      final response = await http.get(Uri.parse(testUrl)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        // Verify it returns valid JSON with categories
        final data = json.decode(response.body);
        if (data['categories'] != null && data['categories'] is List) {
          await _saveDomainAndProceed(normalized);
          return;
        }
      }

      setState(() {
        _errorMessage = 'Could not verify the server. You can still continue and change it later in Settings.';
        _pendingDomain = normalized;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection failed. You can still continue and change it later in Settings.';
        _pendingDomain = domain.startsWith('http') ? domain : 'https://$domain';
      });
    } finally {
      if (mounted) {
        setState(() => _isValidating = false);
      }
    }
  }

  Future<void> _saveDomainAndProceed(String domain) async {
    final domainService = await DomainService.getInstance();
    await domainService.setDomain(domain);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // App logo/icon
                    Icon(
                      Icons.sports,
                      size: 72,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sports Arena',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Live Sports Streaming',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 48),

                    // Domain input section
                    Text(
                      'Enter your streaming server',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter the domain of your streaming provider to get started.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),

                    // Domain text field
                    TextFormField(
                      controller: _domainController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Server domain',
                        hintText: 'example.com',
                        prefixIcon: const Icon(Icons.dns),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                      ),
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleConnect(),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a domain';
                        }
                        // Basic domain validation
                        final trimmed = value.trim();
                        if (!trimmed.contains('.')) {
                          return 'Please enter a valid domain (e.g., example.com)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Error message
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 20,
                              color: Theme.of(context).colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Allow user to continue without validation
                      if (_pendingDomain != null)
                        OutlinedButton.icon(
                          onPressed: () => _saveDomainAndProceed(_pendingDomain!),
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: const Text('Continue anyway'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],

                    // Connect button
                    FilledButton.icon(
                      onPressed: _isValidating ? null : _handleConnect,
                      icon: _isValidating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.link),
                      label: Text(_isValidating ? 'Connecting...' : 'Connect'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Quick tips
                    _buildQuickTips(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickTips(BuildContext context) {
    final isDesktop = PlatformUtils.isDesktop;

    final tips = isDesktop
        ? [
            ('Icons.play_circle_outline', 'Tap a stream to start watching'),
            ('Icons.fullscreen', 'Press F for fullscreen, Esc to exit'),
            ('Icons.filter_list', 'Filter by sport using category tabs'),
            ('Icons.settings', 'Change server or theme in Settings'),
          ]
        : [
            ('Icons.play_circle_outline', 'Tap a stream to start watching'),
            ('Icons.fullscreen', 'Double-tap player for fullscreen'),
            ('Icons.filter_list', 'Filter by sport using category tabs'),
            ('Icons.settings', 'Change server or theme in Settings'),
          ];

    final icons = [
      Icons.play_circle_outline,
      Icons.fullscreen,
      Icons.filter_list,
      Icons.settings,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Quick Tips',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(tips.length, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(icons[i], size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tips[i].$2,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
