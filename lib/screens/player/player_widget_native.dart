import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../../utils/platform_utils.dart';

/// Player widget for native platforms (Android, macOS, Windows).
/// Android: Uses Hybrid Composition so the WebView receives real touch/D-pad events.
/// On TV, a native MotionEvent is dispatched via platform channel for play/pause.
/// macOS: Uses WKWebView with inline media playback enabled.
/// Windows: Uses WebView2 via webview_win_floating (implements webview_flutter API).
class PlayerWidget extends StatefulWidget {
  final String embedUrl;
  final VoidCallback? onDoubleTap;

  const PlayerWidget({super.key, required this.embedUrl, this.onDoubleTap});

  @override
  State<PlayerWidget> createState() => PlayerWidgetState();
}

class PlayerWidgetState extends State<PlayerWidget> {
  late final WebViewController _controller;
  bool _isLoading = true;

  bool get _isDesktop => PlatformUtils.isDesktop;

  @override
  void initState() {
    super.initState();
    _initController();
    _controller.loadRequest(Uri.parse(widget.embedUrl));
    // Safety timeout: dismiss loading after 8 seconds regardless
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  void dispose() {
    // Stop any playing media and clear the WebView to prevent background playback
    _controller.runJavaScript('''
      (function() {
        var videos = document.querySelectorAll('video');
        videos.forEach(function(v) { v.pause(); v.src = ''; v.load(); });
        var audios = document.querySelectorAll('audio');
        audios.forEach(function(a) { a.pause(); a.src = ''; a.load(); });
      })();
    ''');
    _controller.loadRequest(Uri.parse('about:blank'));
    super.dispose();
  }

  void _initController() {
    // macOS/iOS: use WebKit-specific params for inline media playback
    if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      final webKitParams = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
      _controller = WebViewController.fromPlatformCreationParams(webKitParams);
    } else {
      _controller = WebViewController();
    }

    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _isLoading = false);
            _injectPopupBlocker();
            _injectAutoplay();
            if (PlatformUtils.isTv) {
              _injectTvKeyboardHandler();
            }
          },
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description} (${error.errorCode})');
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            final url = request.url;
            if (_isAdUrl(url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    // Android-specific: disable user gesture requirement for media playback
    if (defaultTargetPlatform == TargetPlatform.android) {
      _controller.setBackgroundColor(Colors.black);
      final androidController =
          _controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  bool _isAdUrl(String url) {
    final adPatterns = [
      'doubleclick.net',
      'googlesyndication.com',
      'popads',
      'popunder',
      'clickadu',
      'propellerads',
      'trafficjunky',
      'exoclick',
      'juicyads',
      'adsterra',
      'hilltopads',
      'bet365',
      'stake.com',
      '1xbet',
    ];
    final lowerUrl = url.toLowerCase();
    for (final pattern in adPatterns) {
      if (lowerUrl.contains(pattern)) return true;
    }
    return false;
  }

  void _injectAutoplay() {
    // On TV, be more aggressive with autoplay attempts
    final isTv = PlatformUtils.isTv;
    _controller.runJavaScript('''
      (function() {
        function simulateTouch(el) {
          var rect = el.getBoundingClientRect();
          var cx = rect.left + rect.width / 2;
          var cy = rect.top + rect.height / 2;
          try {
            var touchObj = new Touch({
              identifier: Date.now(),
              target: el,
              clientX: cx,
              clientY: cy,
              radiusX: 2.5,
              radiusY: 2.5,
              rotationAngle: 0,
              force: 0.5
            });
            el.dispatchEvent(new TouchEvent('touchstart', {
              cancelable: true, bubbles: true,
              touches: [touchObj], targetTouches: [touchObj], changedTouches: [touchObj]
            }));
            el.dispatchEvent(new TouchEvent('touchend', {
              cancelable: true, bubbles: true,
              touches: [], targetTouches: [], changedTouches: [touchObj]
            }));
          } catch(e) {}
          el.dispatchEvent(new MouseEvent('click', {bubbles: true, cancelable: true, clientX: cx, clientY: cy}));
        }

        function tryPlay() {
          // Try direct video element
          var video = document.querySelector('video');
          if (video) {
            video.play().catch(function(){});
            return true;
          }
          // Try common play button selectors
          var selectors = [
            '.play-button',
            '.vjs-big-play-button',
            '[aria-label="Play"]',
            '[aria-label="play"]',
            '.plyr__control--overlaid',
            'button[data-plyr="play"]',
            '.jw-icon-playback',
            '.bmpui-ui-hugeplaybacktogglebutton',
            '.video-js .vjs-play-control',
            '[class*="play" i]',
            '[id*="play" i]'
          ];
          for (var i = 0; i < selectors.length; i++) {
            var btn = document.querySelector(selectors[i]);
            if (btn) { simulateTouch(btn); return true; }
          }
          // Try clicking center of viewport (common for overlay play buttons)
          var buttons = document.querySelectorAll('button, [role="button"], div[onclick], a');
          for (var i = 0; i < buttons.length; i++) {
            var rect = buttons[i].getBoundingClientRect();
            var cx = window.innerWidth / 2;
            var cy = window.innerHeight / 2;
            if (Math.abs(rect.left + rect.width/2 - cx) < 200 &&
                Math.abs(rect.top + rect.height/2 - cy) < 200) {
              simulateTouch(buttons[i]);
              return true;
            }
          }
          return false;
        }
        // Multiple attempts - more aggressive on TV
        ${isTv ? '''
        setTimeout(tryPlay, 500);
        setTimeout(tryPlay, 1000);
        setTimeout(tryPlay, 1500);
        setTimeout(tryPlay, 2500);
        setTimeout(tryPlay, 4000);
        setTimeout(tryPlay, 6000);
        ''' : '''
        setTimeout(tryPlay, 1000);
        setTimeout(tryPlay, 2000);
        setTimeout(tryPlay, 3500);
        setTimeout(tryPlay, 5000);
        '''}
      })();
    ''');

    // On TV, also try native tap (trusted event) after delays
    if (isTv && defaultTargetPlatform == TargetPlatform.android) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _platform.invokeMethod<bool>('tapWebViewCenter');
      });
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) _platform.invokeMethod<bool>('tapWebViewCenter');
      });
      Future.delayed(const Duration(seconds: 7), () {
        if (mounted) _platform.invokeMethod<bool>('tapWebViewCenter');
      });
    }
  }

  /// Platform channel for dispatching native touch events
  static const _platform = MethodChannel('com.sportsarena/platform');

  /// Simulate a click in the center of the WebView (for TV D-pad select).
  /// On Android, dispatches a native MotionEvent via platform channel (trusted tap).
  /// Falls back to JavaScript video.play()/pause() on other platforms.
  void simulateCenterClick() async {
    // On Android, use native tap (produces a trusted OS-level touch event)
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final result = await _platform.invokeMethod<bool>('tapWebViewCenter');
        if (result == true) return;
      } catch (_) {}
    }

    // Fallback: try to play/pause video directly via JS
    _controller.runJavaScript('''
      (function() {
        var video = document.querySelector('video');
        if (video && video.paused) { video.play().catch(function(){}); return; }
        if (video && !video.paused) { video.pause(); return; }

        // Click the center element as last resort
        var cx = window.innerWidth / 2;
        var cy = window.innerHeight / 2;
        var el = document.elementFromPoint(cx, cy);
        if (el) { el.click(); }
      })();
    ''');
  }

  void _injectPopupBlocker() {
    _controller.runJavaScript('''
      (function() {
        window.open = function() { return null; };
        try {
          Object.defineProperty(window, 'open', {
            value: function() { return null; },
            writable: false,
            configurable: false
          });
        } catch(e) {}
        document.addEventListener('click', function(e) {
          var el = e.target;
          while (el && el.tagName !== 'A') { el = el.parentElement; }
          if (el && el.tagName === 'A') {
            var target = el.getAttribute('target');
            if (target === '_blank' || target === '_new') {
              e.preventDefault();
              e.stopPropagation();
              e.stopImmediatePropagation();
              return false;
            }
          }
        }, true);
      })();
    ''');
  }

  /// Injects a keyboard handler into the WebView page so that when the
  /// WebView has platform focus on TV, Enter/Space triggers play/pause.
  void _injectTvKeyboardHandler() {
    _controller.runJavaScript('''
      (function() {
        if (window.__tvKeyHandlerInstalled) return;
        window.__tvKeyHandlerInstalled = true;

        // Make body focusable so it can receive key events
        document.body.setAttribute('tabindex', '0');
        document.body.focus();

        document.addEventListener('keydown', function(e) {
          // Enter (13), Space (32), MediaPlayPause (179)
          if (e.keyCode === 13 || e.keyCode === 32 || e.keyCode === 179) {
            e.preventDefault();
            e.stopPropagation();

            // Try to play/pause video directly
            var video = document.querySelector('video');
            if (video) {
              if (video.paused) { video.play().catch(function(){}); }
              else { video.pause(); }
              return;
            }

            // Click the center element (play button overlay)
            var cx = window.innerWidth / 2;
            var cy = window.innerHeight / 2;
            var el = document.elementFromPoint(cx, cy);
            if (el) { el.click(); }
          }
        }, true);
      })();
    ''');
  }

  @override
  Widget build(BuildContext context) {
    // Desktop (macOS/Windows): simple WebViewWidget, no special composition needed
    if (_isDesktop) {
      return Container(
        color: Colors.black,
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              IgnorePointer(
                child: Container(
                  color: Colors.black,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Android: always use Hybrid Composition for proper input handling
    // (needed for D-pad/remote to interact with iframe content on TV)
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          WebViewWidget.fromPlatformCreationParams(
            params: AndroidWebViewWidgetCreationParams(
              controller: _controller.platform,
              displayWithHybridComposition: true,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<VerticalDragGestureRecognizer>(
                  () => VerticalDragGestureRecognizer(),
                ),
                Factory<HorizontalDragGestureRecognizer>(
                  () => HorizontalDragGestureRecognizer(),
                ),
                Factory<TapGestureRecognizer>(
                  () => TapGestureRecognizer(),
                ),
                Factory<LongPressGestureRecognizer>(
                  () => LongPressGestureRecognizer(),
                ),
              },
            ),
          ),
          // Transparent overlay to detect double-tap for fullscreen toggle.
          // Single taps pass through to the WebView via HitTestBehavior.translucent.
          if (widget.onDoubleTap != null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onDoubleTap: widget.onDoubleTap,
              ),
            ),
          if (_isLoading)
            IgnorePointer(
              child: Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
