import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import '../../models/stream_model.dart';
import '../../models/category_model.dart';
import '../../utils/platform_utils.dart';
import '../../utils/time_utils.dart';
import 'player_widget.dart';

class PlayerScreen extends StatefulWidget {
  final SportStream stream;

  const PlayerScreen({super.key, required this.stream});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _isFullscreen = false;
  bool _showFullscreenHint = false;
  Timer? _hintTimer;
  Size? _savedWindowSize;
  Offset? _savedWindowPosition;
  final _playerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Register hardware keyboard listener for TV remote and desktop shortcuts
    if (_isDesktop || PlatformUtils.isTv) {
      HardwareKeyboard.instance.addHandler(_hardwareKeyHandler);
    }
  }

  /// Hardware key handler that works even when WebView has platform focus
  bool _hardwareKeyHandler(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final result = _handleKeyEvent(FocusNode(), event);
    return result == KeyEventResult.handled;
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    if (_isDesktop || PlatformUtils.isTv) {
      HardwareKeyboard.instance.removeHandler(_hardwareKeyHandler);
    }
    if (_isDesktop) {
      // Exit fullscreen and restore window if still active when leaving
      if (_isFullscreen) {
        windowManager.setFullScreen(false).then((_) {
          if (_savedWindowSize != null) {
            windowManager.setSize(_savedWindowSize!);
          }
          if (_savedWindowPosition != null) {
            windowManager.setPosition(_savedWindowPosition!);
          }
        });
      }
    } else {
      // Restore orientation
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows;

  void _toggleFullscreen() async {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    if (_isDesktop) {
      if (_isFullscreen) {
        // Save current window size and position before going fullscreen
        _savedWindowSize = await windowManager.getSize();
        _savedWindowPosition = await windowManager.getPosition();
        await windowManager.setFullScreen(true);
        _showExitHint();
      } else {
        await windowManager.setFullScreen(false);
        // Restore saved window size and position after a brief delay
        // (macOS needs time to animate out of fullscreen)
        await Future.delayed(const Duration(milliseconds: 300));
        if (_savedWindowSize != null) {
          await windowManager.setSize(_savedWindowSize!);
        }
        if (_savedWindowPosition != null) {
          await windowManager.setPosition(_savedWindowPosition!);
        }
      }
    } else {
      // Mobile: use SystemChrome for immersive mode + orientation
      HapticFeedback.mediumImpact();
      if (_isFullscreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        _showExitHint();
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    }
  }

  void _showExitHint() {
    setState(() => _showFullscreenHint = true);
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showFullscreenHint = false);
    });
  }

  /// Handle keyboard shortcuts for desktop and TV remote
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // Android TV: D-pad center / Select / Enter / Media keys → simulate click in player
    if (PlatformUtils.isTv) {
      if (key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.gameButtonA ||
          key == LogicalKeyboardKey.mediaPlayPause ||
          key == LogicalKeyboardKey.mediaPlay ||
          key == LogicalKeyboardKey.space) {
        _simulatePlayerClick();
        return KeyEventResult.handled;
      }
      // Media stop
      if (key == LogicalKeyboardKey.mediaStop ||
          key == LogicalKeyboardKey.mediaPause) {
        _simulatePlayerClick();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (!_isDesktop) return KeyEventResult.ignored;

    // Esc — exit fullscreen
    if (key == LogicalKeyboardKey.escape && _isFullscreen) {
      _toggleFullscreen();
      return KeyEventResult.handled;
    }

    // F — toggle fullscreen
    if (key == LogicalKeyboardKey.keyF &&
        !HardwareKeyboard.instance.isMetaPressed &&
        !HardwareKeyboard.instance.isControlPressed) {
      _toggleFullscreen();
      return KeyEventResult.handled;
    }

    // Cmd+F (macOS) / Ctrl+F (Windows) — toggle fullscreen
    if (key == LogicalKeyboardKey.keyF &&
        (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed)) {
      _toggleFullscreen();
      return KeyEventResult.handled;
    }

    // Space — play/pause
    if (key == LogicalKeyboardKey.space) {
      _simulatePlayerClick();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _simulatePlayerClick() {
    final state = _playerKey.currentState;
    // simulateCenterClick is available on native PlayerWidgetState
    if (state != null) {
      try {
        (state as dynamic).simulateCenterClick();
      } catch (_) {
        // Web platform doesn't support this
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget screen;
    if (_isFullscreen) {
      screen = PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            _toggleFullscreen(); // Back button exits fullscreen
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Semantics(
            label: 'Video player, double-tap to exit fullscreen',
            child: GestureDetector(
            onDoubleTap: _toggleFullscreen,
            child: Stack(
              children: [
                PlayerWidget(key: _playerKey, embedUrl: widget.stream.embedUrl),
                // Fullscreen exit hint overlay
                if (_showFullscreenHint)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: _showFullscreenHint ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isDesktop ? Icons.keyboard : Icons.touch_app,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  _isDesktop
                                      ? 'Press Esc or F to exit fullscreen'
                                      : 'Double-tap or press back to exit fullscreen',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ),
        ),
      );
    } else {
      screen = Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.stream.name,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (widget.stream.viewers > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const Icon(Icons.visibility, size: 16),
                  const SizedBox(width: 4),
                  Text(TimeUtils.formatViewers(widget.stream.viewers)),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: _toggleFullscreen,
            tooltip: 'Fullscreen (F)',
          ),
        ],
      ),
      body: Column(
        children: [
          // Player - takes most of the space
          Expanded(
            child: Container(
              color: Colors.black,
              child: PlayerWidget(key: _playerKey, embedUrl: widget.stream.embedUrl),
            ),
          ),
          // Stream info bar
          _buildInfoBar(context),
        ],
      ),
    );
    }

    // Focus widget for accessibility; key events handled by HardwareKeyboard listener
    return screen;
  }

  Widget _buildInfoBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.stream.league,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            SportCategory.fromName(widget.stream.category).displayName,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          if (widget.stream.isLive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fiber_manual_record, size: 8, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
