import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../../utils/platform_utils.dart';

/// Player widget for native platforms (Android, macOS, Windows).
/// Android Mobile: Uses Hybrid Composition for proper touch handling.
/// Android TV: Uses default texture mode (lighter) since TV uses D-pad, not touch.
/// macOS: Uses WKWebView with inline media playback enabled.
/// Windows: Uses WebView2 via webview_win_floating (implements webview_flutter API).
class PlayerWidget extends StatefulWidget {
  final String embedUrl;

  const PlayerWidget({super.key, required this.embedUrl});

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
            if (btn) { btn.click(); return true; }
          }
          // Try clicking center of viewport (common for overlay play buttons)
          var buttons = document.querySelectorAll('button, [role="button"], div[onclick], a');
          for (var i = 0; i < buttons.length; i++) {
            var rect = buttons[i].getBoundingClientRect();
            var cx = window.innerWidth / 2;
            var cy = window.innerHeight / 2;
            if (Math.abs(rect.left + rect.width/2 - cx) < 200 &&
                Math.abs(rect.top + rect.height/2 - cy) < 200) {
              buttons[i].click();
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
  }

  /// Simulate a click in the center of the WebView (for TV D-pad select)
  void simulateCenterClick() {
    _controller.runJavaScript('''
      (function() {
        // First try to find and click play button
        var video = document.querySelector('video');
        if (video && video.paused) { video.play().catch(function(){}); return; }
        if (video && !video.paused) { video.pause(); return; }

        // Click the center of the page
        var cx = window.innerWidth / 2;
        var cy = window.innerHeight / 2;
        var el = document.elementFromPoint(cx, cy);
        if (el) {
          el.click();
          // Also dispatch pointer events for players that listen to those
          el.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, clientX: cx, clientY: cy}));
          el.dispatchEvent(new MouseEvent('mouseup', {bubbles: true, clientX: cx, clientY: cy}));
          el.dispatchEvent(new MouseEvent('click', {bubbles: true, clientX: cx, clientY: cy}));
        }
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
