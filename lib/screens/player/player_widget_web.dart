import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
// ignore: undefined_prefixed_name
import 'dart:ui_web' as ui_web;
import 'dart:async';

/// Player widget for Flutter Web.
/// No sandbox (server requires it absent).
/// Popup blocking is handled globally in index.html.
class PlayerWidget extends StatefulWidget {
  final String embedUrl;
  final VoidCallback? onDoubleTap;

  const PlayerWidget({super.key, required this.embedUrl, this.onDoubleTap});

  @override
  State<PlayerWidget> createState() => _PlayerWidgetState();
}

class _PlayerWidgetState extends State<PlayerWidget> {
  late final String _viewId;
  Timer? _sandboxRemovalTimer;

  @override
  void initState() {
    super.initState();
    _viewId = 'stream-player-${DateTime.now().millisecondsSinceEpoch}';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..id = _viewId
          ..src = widget.embedUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allowFullscreen = true
          ..allow = 'fullscreen; picture-in-picture; encrypted-media; autoplay';
        // No sandbox — server rejects it
        iframe.removeAttribute('sandbox');
        return iframe;
      },
    );

    // Remove sandbox from Flutter's wrapper iframes
    _sandboxRemovalTimer = Timer.periodic(
      const Duration(milliseconds: 300),
      (_) => _removeSandboxAttributes(),
    );

    Future.delayed(const Duration(seconds: 2), () {
      _sandboxRemovalTimer?.cancel();
    });
  }

  void _removeSandboxAttributes() {
    final allIframes = html.document.querySelectorAll('iframe');
    for (final element in allIframes) {
      if (element is html.IFrameElement &&
          element.getAttribute('sandbox') != null) {
        element.removeAttribute('sandbox');
      }
    }
  }

  @override
  void dispose() {
    _sandboxRemovalTimer?.cancel();
    // Remove the iframe to stop playback when navigating away
    final iframe = html.document.getElementById(_viewId);
    if (iframe is html.IFrameElement) {
      iframe.src = '';
      iframe.remove();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewId);
  }
}
