import 'package:flutter/material.dart';
import '../../utils/platform_utils.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  bool get _isDesktop => PlatformUtils.isDesktop;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Tips'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            context,
            icon: Icons.play_circle_outline,
            title: 'Watching Streams',
            tips: [
              'Tap on any stream card to start watching',
              'The player loads the stream automatically',
              'Use pull-to-refresh on the home screen to update the stream list',
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            icon: Icons.fullscreen,
            title: 'Fullscreen',
            tips: _isDesktop
                ? [
                    'Press F to toggle fullscreen',
                    'Press Esc to exit fullscreen',
                    'Cmd+F (macOS) or Ctrl+F (Windows) also toggles fullscreen',
                    'Double-click the player to toggle fullscreen',
                    'Click the fullscreen icon in the toolbar',
                  ]
                : [
                    'Tap the fullscreen icon in the top-right corner',
                    'Double-tap the player to toggle fullscreen',
                    'Press the back button to exit fullscreen',
                  ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            icon: Icons.filter_list,
            title: 'Filtering & Sorting',
            tips: [
              'Use the category chips at the top to filter by sport',
              'Tap the sort button to order by viewers, time, name, or league',
              'Set a default category in Settings to auto-filter on launch',
            ],
          ),
          const SizedBox(height: 16),
          if (_isDesktop) ...[
            _buildSection(
              context,
              icon: Icons.keyboard,
              title: 'Keyboard Shortcuts',
              tips: [
                'F - Toggle fullscreen',
                'Esc - Exit fullscreen',
                'Cmd/Ctrl + F - Toggle fullscreen',
              ],
            ),
            const SizedBox(height: 16),
          ],
          _buildSection(
            context,
            icon: Icons.dns,
            title: 'Server Setup',
            tips: [
              'Enter your streaming server domain in Settings > Server',
              'Use "Test" button to verify the connection',
              'You can change the server anytime from Settings',
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            icon: Icons.palette,
            title: 'Appearance',
            tips: [
              'Switch between Dark, Light, or System theme in Settings',
              'The app follows your system theme when set to "System"',
            ],
          ),
          const SizedBox(height: 16),
          if (!_isDesktop)
            _buildSection(
              context,
              icon: Icons.tv,
              title: 'Android TV / Fire Stick',
              tips: [
                'Use D-pad to navigate between streams',
                'Press Select/Enter to open a stream',
                'Press Back to return to the stream list',
                'Install via Downloader app with code: 9563542',
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<String> tips,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('  \u2022  ', style: TextStyle(fontSize: 14)),
                    Expanded(
                      child: Text(
                        tip,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
