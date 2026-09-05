import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../../models/stream_model.dart';
import '../../providers/settings_provider.dart';
import '../../providers/streams_provider.dart';
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

  /// The stream with playback sources resolved. Starts as the list item passed
  /// in (which has no sources), then gets replaced by the detail fetch.
  late SportStream _stream;
  bool _resolvingSource = false;
  String? _sourceError;

  /// Currently selected playback source URL (quality). Null until resolved.
  String? _selectedSourceUrl;

  GlobalKey _playerKey = GlobalKey();
  final _backFocusNode = FocusNode(debugLabel: 'Back Button');
  final _playPauseFocusNode = FocusNode(debugLabel: 'Play/Pause Button');
  final _qualityFocusNode = FocusNode(debugLabel: 'Quality Button');
  final _fullscreenFocusNode = FocusNode(debugLabel: 'Fullscreen Button');

  @override
  void initState() {
    super.initState();
    _stream = widget.stream; // initial (list item, no sources yet)
    // Register hardware keyboard listener for desktop shortcuts and TV remote.
    // On TV, we intercept Enter/Select to dispatch a native tap to the WebView
    // (producing a trusted MotionEvent that satisfies autoplay policies).
    if (_isDesktop || PlatformUtils.isTv) {
      HardwareKeyboard.instance.addHandler(_hardwareKeyHandler);
    }
    _startOverlayTimer();
    // The streams-list item has no playback sources — fetch the stream detail
    // to get the `sources` array before we can load the embed player.
    if (!_stream.hasSource) {
      _resolveSource();
    } else {
      final preferred = context.read<SettingsProvider>().preferredQuality;
      _selectedSourceUrl = _stream.sourceForPreferredHeight(preferred)?.url;
    }
  }

  /// Switch to a different quality/source. Reassigns the player key so the
  /// WebView fully reinitializes with the new URL.
  void _selectSource(StreamSource source) {
    if (source.url == _selectedSourceUrl) return;
    setState(() {
      _selectedSourceUrl = source.url;
      _playerKey = GlobalKey(); // force WebView rebuild with the new URL
    });
    _showOverlayAndResetTimer();
  }

  /// Fetch the single-stream detail to populate playback sources.
  Future<void> _resolveSource() async {
    setState(() {
      _resolvingSource = true;
      _sourceError = null;
    });
    try {
      final provider = context.read<StreamsProvider>();
      final detail = await provider.getStreamDetail(_stream.streamKey);
      if (!mounted) return;
      if (detail != null && detail.hasSource) {
        setState(() {
          _stream = detail;
          _resolvingSource = false;
          // Pick the source matching the user's preferred quality (default 1080p).
          final preferred = context.read<SettingsProvider>().preferredQuality;
          _selectedSourceUrl = detail.sourceForPreferredHeight(preferred)?.url;
        });
      } else {
        setState(() {
          _resolvingSource = false;
          _sourceError = 'No playable source found for this stream.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resolvingSource = false;
        _sourceError = 'Could not load the stream. Please try again.';
      });
    }
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
    // Auto-hide on TV and desktop (like YouTube/Netflix behavior)
    if (!PlatformUtils.isTv && !_isDesktop) return;
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
    _playPauseFocusNode.dispose();
    _qualityFocusNode.dispose();
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
        if (!_backFocusNode.hasFocus &&
            !_playPauseFocusNode.hasFocus &&
            !_qualityFocusNode.hasFocus &&
            !_fullscreenFocusNode.hasFocus) {
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
        final hasQuality = _stream.labeledSources.length > 1;
        if (!_backFocusNode.hasFocus &&
            !_playPauseFocusNode.hasFocus &&
            !_qualityFocusNode.hasFocus &&
            !_fullscreenFocusNode.hasFocus) {
          // Nothing focused — first press focuses play/pause (most useful action)
          _playPauseFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
        // Move between buttons:
        //   back ↔ play/pause ↔ [quality] ↔ fullscreen
        if (key == LogicalKeyboardKey.arrowLeft) {
          if (_fullscreenFocusNode.hasFocus) {
            (hasQuality ? _qualityFocusNode : _playPauseFocusNode).requestFocus();
            return KeyEventResult.handled;
          }
          if (_qualityFocusNode.hasFocus) {
            _playPauseFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
          if (_playPauseFocusNode.hasFocus) {
            _backFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          if (_backFocusNode.hasFocus) {
            _playPauseFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
          if (_playPauseFocusNode.hasFocus) {
            (hasQuality ? _qualityFocusNode : _fullscreenFocusNode).requestFocus();
            return KeyEventResult.handled;
          }
          if (_qualityFocusNode.hasFocus) {
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

  bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

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
            child: _isWindows
                // Windows: Column layout (header above WebView) because
                // webview_win_floating renders a native window on top of Flutter.
                ? Column(
                    children: [
                      _buildWindowsHeader(context),
                      Expanded(
                        child: _buildPlayerArea(),
                      ),
                    ],
                  )
                : Stack(
              children: [
                _buildPlayerArea(),
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
    } else if (_isWindows) {
      // Windows non-fullscreen: Column layout with header above WebView
      screen = Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            _buildWindowsHeader(context),
            Expanded(
              child: _buildPlayerArea(),
            ),
          ],
        ),
      );
    } else {
      screen = Scaffold(
      backgroundColor: Colors.black,
      body: MouseRegion(
        onHover: _isDesktop ? (_) => _showOverlayAndResetTimer() : null,
        onEnter: _isDesktop ? (_) => _showOverlayAndResetTimer() : null,
        child: GestureDetector(
          onTap: _showOverlayAndResetTimer,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              // Player takes full space
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: _buildPlayerArea(),
                ),
              ),
              // Top overlay with back, title, info, fullscreen — auto-hides
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
                                _stream.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_stream.viewers > 0) ...[
                              const Icon(Icons.visibility, size: 14, color: Colors.white60),
                              const SizedBox(width: 4),
                              Text(
                                TimeUtils.formatViewers(_stream.viewers),
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                              const SizedBox(width: 10),
                            ],
                            if (_stream.isLive) ...[
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
                            // Quality selector — plain text label, only when
                            // more than one source is available
                            if (_stream.labeledSources.length > 1) ...[
                              _buildQualityLabel(order: 2),
                              const SizedBox(width: 10),
                            ],
                            _buildFocusableButton(
                              icon: Icons.fullscreen,
                              onPressed: _toggleFullscreen,
                              tooltip: 'Fullscreen',
                              focusNode: _fullscreenFocusNode,
                              order: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Three-dots icon in back-button position — appears when overlay is hidden
              if (!_showOverlay)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 12,
                  child: GestureDetector(
                    onTap: _showOverlayAndResetTimer,
                    child: Semantics(
                      button: true,
                      label: 'Show controls',
                      child: Icon(
                        Icons.more_horiz,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 24,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    }

    // Key events handled by HardwareKeyboard listener
    return screen;
  }

  /// Builds the player area: a loader while the stream source is being
  /// resolved, an error message if none is found, or the WebView player.
  Widget _buildPlayerArea() {
    if (_resolvingSource) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }
    if (_sourceError != null || !_stream.hasSource) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white54, size: 40),
              const SizedBox(height: 12),
              Text(
                _sourceError ?? 'No playable source found for this stream.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _resolveSource,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }
    return PlayerWidget(
      key: _playerKey,
      embedUrl: _selectedSourceUrl ?? _stream.embedUrl,
      onDoubleTap: _toggleFullscreen,
    );
  }

  /// Current source's friendly label, e.g. "1080p". Empty if unresolved.
  String get _currentQualityLabel {
    if (_selectedSourceUrl == null) return '';
    final match =
        _stream.labeledSources.where((s) => s.url == _selectedSourceUrl);
    return match.isEmpty ? '' : match.first.label;
  }

  /// A plain-text quality label (e.g. "1080p") that blends in with the other
  /// overlay text (viewers / LIVE), tappable to open the quality picker.
  /// On TV it shows a subtle underline/highlight when D-pad focused.
  Widget _buildQualityLabel({required int order}) {
    return FocusTraversalOrder(
      order: NumericFocusOrder(order.toDouble()),
      child: Focus(
        focusNode: _qualityFocusNode,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.space)) {
            _showQualityPicker();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) {
            final isFocused = Focus.of(context).hasFocus;
            return GestureDetector(
              onTap: _showQualityPicker,
              child: Semantics(
                button: true,
                label: 'Quality $_currentQualityLabel. Tap to change.',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: isFocused ? Colors.white24 : Colors.transparent,
                  ),
                  child: Text(
                    _currentQualityLabel,
                    style: TextStyle(
                      color: isFocused ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Show a bottom sheet (mobile) / menu of available qualities.
  void _showQualityPicker() {
    _showOverlayAndResetTimer();
    final sources = _stream.labeledSources;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    const Icon(Icons.hd_outlined, size: 18, color: Colors.white70),
                    const SizedBox(width: 8),
                    const Text(
                      'Quality',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ...sources.map((source) {
                final selected = source.url == _selectedSourceUrl;
                return ListTile(
                  leading: Icon(
                    selected ? Icons.check_circle : Icons.high_quality_outlined,
                    color: selected ? Theme.of(context).colorScheme.primary : Colors.white54,
                  ),
                  title: Text(
                    source.label,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _selectSource(source);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// Builds a solid header bar for Windows.
  /// On Windows, webview_win_floating renders a native window ON TOP of Flutter,
  /// so we cannot overlay Flutter widgets above it. Instead we use a Column
  /// layout with this header above the WebView area.
  Widget _buildWindowsHeader(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        left: 8,
        right: 8,
        bottom: 4,
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
                _stream.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_stream.viewers > 0) ...[
              const Icon(Icons.visibility, size: 14, color: Colors.white60),
              const SizedBox(width: 4),
              Text(
                TimeUtils.formatViewers(_stream.viewers),
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(width: 10),
            ],
            if (_stream.isLive) ...[
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
              icon: Icons.play_arrow,
              onPressed: _simulatePlayerClick,
              tooltip: 'Play / Pause',
              focusNode: _playPauseFocusNode,
              order: 2,
            ),
            const SizedBox(width: 4),
            if (_stream.labeledSources.length > 1) ...[
              _buildQualityLabel(order: 3),
              const SizedBox(width: 10),
            ],
            _buildFocusableButton(
              icon: _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
              onPressed: _toggleFullscreen,
              tooltip: _isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
              focusNode: _fullscreenFocusNode,
              order: 4,
            ),
          ],
        ),
      ),
    );
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
