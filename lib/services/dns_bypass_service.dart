import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config/blocked_domains.dart';

/// DNS bypass service that runs a local CONNECT proxy.
///
/// Problem: ISP returns blocked IPs for certain domains.
/// Solution: Resolve domains via DNS-over-HTTPS (DoH), then connect
/// to the correct (unblocked) IP.
///
/// Architecture:
/// - Runs a local HTTP CONNECT proxy on localhost
/// - Resolves domains via Cloudflare/Google DoH
/// - Connects to the DoH-resolved IP with proper TLS SNI
/// - Dart HttpClient uses this proxy via HttpOverrides.findProxy
/// - WebView uses it via proxy configuration (Android) or
///   loads content fetched through it (macOS)
///
/// The CONNECT proxy method is how all real proxies work:
/// 1. Client sends: CONNECT example.com:443 HTTP/1.1
/// 2. Proxy resolves example.com via DoH → gets unblocked IP
/// 3. Proxy connects to that IP on port 443
/// 4. Proxy responds: HTTP/1.1 200 Connection established
/// 5. Client does TLS handshake through the tunnel (SNI = example.com)
/// 6. Everything works — no mixed content, proper certs, full HTTPS
class DnsBypassService {
  static final DnsBypassService _instance = DnsBypassService._();
  factory DnsBypassService() => _instance;
  DnsBypassService._();

  HttpServer? _proxyServer;
  int _port = 0;
  bool _enabled = true;

  /// DoH server URL — use domain-based endpoints, NOT direct IPs.
  /// ISPs that block sites often also block 1.1.1.1/8.8.8.8 by IP.
  /// Domain-based DoH URLs resolve to different IPs that aren't blocked.
  String _dohServer = 'https://cloudflare-dns.com/dns-query';

  /// Fallback DoH servers tried in order if the primary times out.
  /// Keeps the bypass working even if the ISP blocks one DoH provider.
  ///
  /// NOTE: IP-based endpoints (1.1.1.1, 8.8.8.8) are included because on
  /// Android emulators, the system DNS for domain-based DoH endpoints
  /// (cloudflare-dns.com, dns.google) may itself be poisoned or slow.
  /// IP endpoints skip DNS entirely. Only Cloudflare, Google, and NextDNS
  /// are listed — they all support the JSON API (?name=&type=A).
  /// Quad9 and OpenDNS only support RFC 8484 wire format (not JSON).
  static const List<String> _fallbackDohServers = [
    'https://cloudflare-dns.com/dns-query',
    'https://1.1.1.1/dns-query',
    'https://dns.google/resolve',
    'https://8.8.8.8/resolve',
    'https://dns.nextdns.io/dns-query',
  ];

  /// DNS cache: domain → IP
  final Map<String, _DnsCacheEntry> _cache = {};
  static const int _cacheTtl = 300; // 5 minutes

  // ─── Public API ───────────────────────────────────────

  bool get isEnabled => _enabled;
  bool get isRunning => _proxyServer != null;
  int get port => _port;
  String get dohServer => _dohServer;

  /// Start the bypass service
  Future<void> start() async {
    if (_proxyServer != null || !_enabled) return;

    try {
      _proxyServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _proxyServer!.port;
      debugPrint('DNS bypass proxy started on localhost:$_port');
      _proxyServer!.listen(_handleRequest, onError: (e) {
        debugPrint('Proxy error: $e');
      });
    } catch (e) {
      debugPrint('Failed to start DNS bypass proxy: $e');
      _proxyServer = null;
    }
  }

  /// Stop the service
  Future<void> stop() async {
    await _proxyServer?.close(force: true);
    _proxyServer = null;
    _port = 0;
    // Clean up Windows user proxy on stop
    await _clearWindowsProxy();
  }

  /// Remove the Windows user-level proxy setting so the system returns to
  /// direct connections after the app exits or proxy is disabled.
  Future<void> _clearWindowsProxy() async {
    if (!Platform.isWindows) return;
    try {
      await Process.run('reg', [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v', 'ProxyEnable',
        '/t', 'REG_DWORD',
        '/d', '0',
        '/f',
      ]);
      debugPrint('Windows user proxy disabled');
    } catch (e) {
      debugPrint('Failed to clear Windows proxy: $e');
    }
  }

  /// Enable/disable the service
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    if (enabled && !isRunning) {
      await start();
    } else if (!enabled && isRunning) {
      await stop();
    }
  }

  /// Set the DoH server URL
  void setDohServer(String url) {
    _dohServer = url;
    _cache.clear();
  }

  /// Clear DNS cache
  void clearCache() => _cache.clear();

  /// Get the proxy string for HttpClient.findProxy
  /// Returns 'PROXY localhost:PORT' or 'DIRECT'
  String getProxyConfig() {
    if (!_enabled || !isRunning) return 'DIRECT';
    return 'PROXY localhost:$_port';
  }

  // ─── CONNECT Proxy Handler ────────────────────────────

  /// Check if a domain (or any of its parent domains) is in the block list
  bool _isBlockedDomain(String host) {
    if (BlockedDomains.all.contains(host)) return true;
    // Check parent domains (e.g., sub.adclickad.com → adclickad.com)
    final parts = host.split('.');
    for (int i = 1; i < parts.length - 1; i++) {
      final parent = parts.sublist(i).join('.');
      if (BlockedDomains.all.contains(parent)) return true;
    }
    return false;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.method == 'CONNECT') {
      await _handleConnect(request);
    } else {
      // Regular HTTP proxy request (non-TLS)
      await _handleHttpProxy(request);
    }
  }

  /// Handle CONNECT tunneling (for HTTPS)
  Future<void> _handleConnect(HttpRequest request) async {
    final target = request.uri.toString(); // e.g., "example.com:443"
    final parts = target.split(':');
    final host = parts[0];
    final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 443 : 443;

    // Block ad/tracking domains at the proxy level
    if (_isBlockedDomain(host)) {
      debugPrint('CONNECT proxy: BLOCKED ad domain $host');
      try {
        request.response
          ..statusCode = 502
          ..write('Blocked')
          ..close();
      } catch (_) {}
      return;
    }

    debugPrint('CONNECT proxy: tunnel request for $host:$port');

    try {
      // Resolve via DoH
      final resolvedIp = await _resolveHost(host);
      final connectHost = resolvedIp ?? host;
      debugPrint('CONNECT proxy: resolved $host → $connectHost');

      // Connect to the resolved IP
      final targetSocket = await Socket.connect(
        connectHost,
        port,
        timeout: const Duration(seconds: 10),
      );

      debugPrint('CONNECT proxy: connected to $connectHost:$port');

      // Detach the client socket and send 200 manually.
      // Using detachSocket(writeHeaders: false) so we control the response bytes exactly.
      final clientSocket = await request.response.detachSocket(writeHeaders: false);

      // Send the CONNECT success response manually
      clientSocket.add('HTTP/1.1 200 Connection established\r\n\r\n'.codeUnits);

      // Track if this is the first data from client (TLS ClientHello)
      bool firstClientData = true;

      // Bidirectional pipe: relay all bytes between client and target
      // For the first client→target write (TLS ClientHello), fragment it
      // to bypass SNI-based DPI inspection.
      clientSocket.listen(
        (data) async {
          try {
            if (firstClientData && data.length > 10) {
              firstClientData = false;
              // Fragment the TLS ClientHello into small TCP segments.
              // DPI systems inspect the first packet for SNI — by splitting
              // it into tiny pieces and flushing each one, the SNI spans
              // multiple TCP packets and most DPI systems can't reassemble it.
              await _writeFragmented(targetSocket, data);
            } else {
              targetSocket.add(data);
            }
          } catch (_) {}
        },
        onDone: () => targetSocket.destroy(),
        onError: (_) => targetSocket.destroy(),
      );
      targetSocket.listen(
        (data) {
          try { clientSocket.add(data); } catch (_) {}
        },
        onDone: () => clientSocket.destroy(),
        onError: (_) => clientSocket.destroy(),
      );
    } catch (e) {
      debugPrint('CONNECT tunnel failed for $host: $e');
      try {
        request.response
          ..statusCode = 502
          ..write('Connection failed')
          ..close();
      } catch (_) {}
    }
  }

  /// Handle plain HTTP proxy requests (non-HTTPS)
  Future<void> _handleHttpProxy(HttpRequest request) async {
    final targetUri = request.uri;
    final host = targetUri.host;

    try {
      final resolvedIp = await _resolveHost(host);
      final connectHost = resolvedIp ?? host;
      final resolvedUri = targetUri.replace(host: connectHost);

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      client.findProxy = (uri) => 'DIRECT'; // Don't route through ourselves

      try {
        final proxyReq = await client.openUrl(request.method, resolvedUri);
        proxyReq.headers.set('Host', host);

        // Forward headers
        request.headers.forEach((name, values) {
          if (name.toLowerCase() == 'host') return;
          if (name.toLowerCase() == 'proxy-connection') return;
          for (final v in values) {
            proxyReq.headers.add(name, v);
          }
        });

        // Forward body
        if (request.contentLength > 0) {
          await for (final chunk in request) {
            proxyReq.add(chunk);
          }
        }

        final proxyRes = await proxyReq.close();

        // Forward response
        request.response.statusCode = proxyRes.statusCode;
        proxyRes.headers.forEach((name, values) {
          for (final v in values) {
            request.response.headers.add(name, v);
          }
        });
        await proxyRes.pipe(request.response);
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('HTTP proxy failed for $host: $e');
      try {
        request.response
          ..statusCode = 502
          ..write('Proxy error')
          ..close();
      } catch (_) {}
    }
  }

  // ─── DoH Resolution ───────────────────────────────────

  Future<String?> _resolveHost(String host) async {
    // Skip if it's already an IP
    if (_isIp(host)) return host;

    // Check cache
    final cached = _cache[host];
    if (cached != null &&
        DateTime.now().difference(cached.time).inSeconds < _cacheTtl) {
      return cached.ip;
    }

    // Try primary DoH server first, then fallbacks
    final serversToTry = <String>[
      _dohServer,
      ..._fallbackDohServers.where((s) => s != _dohServer),
    ];

    for (final server in serversToTry) {
      try {
        final ip = await _dohResolve(host, server);
        if (ip != null) {
          _cache[host] = _DnsCacheEntry(ip: ip, time: DateTime.now());
          return ip;
        }
      } catch (e) {
        debugPrint('DoH resolve failed for $host via $server: $e');
      }
    }

    return null; // All DoH servers failed — fall back to system DNS
  }

  Future<String?> _dohResolve(String domain, String dohServerUrl) async {
    final uri = Uri.parse(dohServerUrl).replace(queryParameters: {
      'name': domain,
      'type': 'A',
    });

    // IMPORTANT: Create HttpClient with findProxy = DIRECT to avoid routing
    // DoH requests through our own proxy (which would be circular).
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    client.findProxy = (uri) => 'DIRECT';
    try {
      debugPrint('DoH: resolving $domain via $dohServerUrl');
      final req = await client.getUrl(uri);
      req.headers.set('Accept', 'application/dns-json');
      final res = await req.close().timeout(const Duration(seconds: 5));
      debugPrint('DoH: got response ${res.statusCode} for $domain');
      if (res.statusCode != 200) return null;

      final body = await res.cast<List<int>>().transform(utf8.decoder).join();
      final data = json.decode(body);
      final answers = data['Answer'] as List?;
      if (answers == null) return null;

      for (final a in answers) {
        if (a['type'] == 1) return a['data'] as String;
      }
      return null;
    } finally {
      client.close();
    }
  }

  bool _isIp(String host) {
    return RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host) ||
        host.contains(':');
  }

  /// Fragment a TLS ClientHello into small TCP segments to bypass DPI.
  ///
  /// Most DPI systems inspect only the first TCP segment for the SNI field.
  /// By splitting the ClientHello into tiny pieces and flushing each one,
  /// the SNI spans multiple TCP packets and DPI systems can't reassemble it.
  /// The server reassembles the fragments normally (TCP handles this).
  ///
  /// CRITICAL: We must call socket.flush() after each fragment to force it
  /// into a separate TCP segment. Without flush(), Dart's socket layer may
  /// buffer multiple add() calls into a single TCP packet, defeating the
  /// purpose of fragmentation entirely.
  Future<void> _writeFragmented(Socket target, List<int> data) async {
    // Fragment size: small enough that SNI can't be read from any single segment.
    // 5 bytes is what works in practice — DPI needs ~20+ contiguous bytes to
    // extract the SNI hostname from the ClientHello.
    const fragmentSize = 5;
    int offset = 0;
    while (offset < data.length) {
      final end = (offset + fragmentSize).clamp(0, data.length);
      target.add(data.sublist(offset, end));
      // Flush forces each fragment into its own TCP segment.
      // This is what makes fragmentation actually work — without it,
      // Nagle's algorithm or Dart's internal buffering combines them.
      await target.flush();
      offset = end;
    }
  }
}

class _DnsCacheEntry {
  final String ip;
  final DateTime time;
  _DnsCacheEntry({required this.ip, required this.time});
}

/// HttpOverrides that routes all Dart HTTP traffic through the DNS bypass proxy.
/// Install via: HttpOverrides.global = DnsBypassHttpOverrides();
class DnsBypassHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    // Route through our local CONNECT proxy
    client.findProxy = (uri) => DnsBypassService().getProxyConfig();
    return client;
  }
}
