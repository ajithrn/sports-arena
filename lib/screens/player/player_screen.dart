import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import '../../models/stream_model.dart';
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
  bool _showOverlay = true;
  Timer? _hintTimer;
  Timer? _overlayTimer;
  Size? _savedWindowSize;
  Offset? _savedWindowPosition;
  final _playerKey = GlobalKey();
  final _backFocusNode = FocusNode(debugLabel: 'Back Button');
  final _fullscreenFocusNode = FocusNode(debugLabel: 'Fullscreen Button');

  @override
  void initState() {
    super.initState();
    // Register hardware keyboard listener for desktop shortcuts and TV remote.
    // On TV, we intercept Enter/Select to dispatch a native tap to the WebView
    // (producing a trusted MotionEvent that satisfies autoplay policies).
    if (_isDesktop || PlatformUtils.isTv) {
      HardwareKeyboard.instance.addHandler(_hardwareKeyHandler);
    }
    _startOverlayTimer();
  }

  /// Hardware key handler that works even when WebView has platform focus
  bool _hardwareKeyHandler(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    // Any key press shows the overlay
    _showOverlayAndResetTimer();
    final result = _handleKeyEvent(FocusNode(), event);
    return result == KeyEventResult.handled;
  }

  void _startOverlayTimer() {
    // Only auto-hide on TV
    if (!PlatformUtils.isTv) return;
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showOverlay = false);
    });
  }

  void _showOverlayAndResetTimer() {
    if (!_showOverlay && mounted) {
      setState(() => _showOverlay = true);
    }
    _startOverlayTimer();
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _overlayTimer?.cancel();
    _backFocusNode.dispose();
    _fullscreenFocusNode.dispose();
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

  bool get _isDesktop => PlatformUtils.isDesktop;

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

    // Android TV: Intercept D-pad center/Enter/Select to dispatch a native
    // trusted tap to the WebView via platform channel.
    if (PlatformUtils.isTv) {
      if (key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.gameButtonA ||
          key == LogicalKeyboardKey.mediaPlayPause ||
          key == LogicalKeyboardKey.mediaPlay ||
          key == LogicalKeyboardKey.space) {
        // Only trigger play/pause if no button is currently focused
        if (!_backFocusNode.hasFocus && !_fullscreenFocusNode.hasFocus) {
          _simulatePlayerClick();
          return KeyEventResult.handled;
        }
        // If a button is focused, let the Focus onKeyEvent handle it
        return KeyEventResult.ignored;
      }
      if (key == LogicalKeyboardKey.mediaStop ||
          key == LogicalKeyboardKey.mediaPause) {
        _simulatePlayerClick();
        return KeyEventResult.handled;
      }
      // D-pad arrows: manually handle focus movement between buttons
      if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight ||
          key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.arrowDown) {
        if (!_backFocusNode.hasFocus && !_fullscreenFocusNode.hasFocus) {
          // Nothing focused — first press focuses fullscreen
          _fullscreenFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
        // Move between buttons
        if (key == LogicalKeyboardKey.arrowLeft) {
          if (_fullscreenFocusNode.hasFocus) {
            _backFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          if (_backFocusNode.hasFocus) {
            _fullscreenFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
        }
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
    // After native tap, the WebView platform view grabs Android focus.
    // Show the overlay so user knows they can navigate, but don't force focus
    // on any button — let user initiate with D-pad.
    if (PlatformUtils.isTv) {
      _showOverlayAndResetTimer();
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
      body: GestureDetector(
        onTap: _showOverlayAndResetTimer,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // Player takes full space
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: PlayerWidget(key: _playerKey, embedUrl: widget.stream.embedUrl),
              ),
            ),
            // Top overlay with back, title, info, fullscreen — auto-hides on TV
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: IgnorePointer(
                ignoring: !_showOverlay,
                child: AnimatedOpacity(
                  opacity: _showOverlay ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 8,
                      right: 8,
                      bottom: 20,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black87,
                          Colors.black45,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.6, 1.0],
                      ),
                    ),
                    child: FocusTraversalGroup(
                      policy: OrderedTraversalPolicy(),
                      child: Row(
                        children: [
                          _buildFocusableButton(
                            icon: Icons.arrow_back,
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'Back',
                            focusNode: _backFocusNode,
                            order: 1,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.stream.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.stream.viewers > 0) ...[
                            const Icon(Icons.visibility, size: 14, color: Colors.white60),
                            const SizedBox(width: 4),
                            Text(
                              TimeUtils.formatViewers(widget.stream.viewers),
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                            const SizedBox(width: 10),
                          ],
                          if (widget.stream.isLive) ...[
                            const Icon(Icons.fiber_manual_record, size: 8, color: Colors.redAccent),
                            const SizedBox(width: 4),
                            const Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          _buildFocusableButton(
                            icon: Icons.fullscreen,
                            onPressed: _toggleFullscreen,
                            tooltip: 'Fullscreen',
                            focusNode: _fullscreenFocusNode,
                            order: 2,
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
    );
    }

    // Key events handled by HardwareKeyboard listener
    return screen;
  }

  /// Icon button: invisible at rest, dark circular bg + white border on D-pad focus
  Widget _buildFocusableButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    FocusNode? focusNode,
    double size = 24,
    bool autofocus = false,
    int order = 0,
  }) {
    return FocusTraversalOrder(
      order: NumericFocusOrder(order.toDouble()),
      child: Focus(
        focusNode: focusNode,
        autofocus: autofocus,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
               event.logicalKey == LogicalKeyboardKey.select ||
               event.logicalKey == LogicalKeyboardKey.space)) {
            onPressed();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) {
            final isFocused = Focus.of(context).hasFocus;
            return GestureDetector(
              onTap: onPressed,
              child: Semantics(
                button: true,
                label: tooltip,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFocused ? Colors.black87 : Colors.transparent,
                    border: Border.all(
                      color: isFocused ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: size,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
