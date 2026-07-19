import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../../utils/platform_utils.dart';

/// Player widget for Android (mobile & TV).
/// Mobile: Uses Hybrid Composition for proper touch handling.
/// TV: Uses default texture mode (lighter) since TV uses D-pad, not touch.
class PlayerWidget extends StatefulWidget {
  final String embedUrl;

  const PlayerWidget({super.key, required this.embedUrl});

  @override
  State<PlayerWidget> createState() => _PlayerWidgetState();
}

class _PlayerWidgetState extends State<PlayerWidget> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
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

    // Android-specific
    final androidController =
        _controller.platform as AndroidWebViewController;
    androidController.setMediaPlaybackRequiresUserGesture(false);

    _controller.loadRequest(Uri.parse(widget.embedUrl));
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
    _controller.runJavaScript('''
      (function() {
        function tryPlay() {
          var video = document.querySelector('video');
          if (video) { video.play().catch(function(){}); return; }
          var playBtn = document.querySelector('.play-button, .vjs-big-play-button, [aria-label="Play"], .plyr__control--overlaid, button[data-plyr="play"]');
          if (playBtn) { playBtn.click(); return; }
          var buttons = document.querySelectorAll('button, [role="button"]');
          for (var i = 0; i < buttons.length; i++) {
            var rect = buttons[i].getBoundingClientRect();
            var cx = window.innerWidth / 2;
            var cy = window.innerHeight / 2;
            if (Math.abs(rect.left + rect.width/2 - cx) < 200 &&
                Math.abs(rect.top + rect.height/2 - cy) < 200) {
              buttons[i].click();
              break;
            }
          }
        }
        setTimeout(tryPlay, 1500);
        setTimeout(tryPlay, 3000);
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
    final useHybrid = !PlatformUtils.isTv;

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          if (useHybrid)
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
            )
          else
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
}
