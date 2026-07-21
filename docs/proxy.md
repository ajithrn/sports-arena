# DNS Bypass Proxy

Local CONNECT proxy that bypasses ISP blocking (DNS poisoning + SNI-based DPI) so streams play on restricted networks.

## Problem

ISPs block streaming sites using two techniques:
1. **DNS poisoning** — system DNS returns a fake/unreachable IP for blocked domains
2. **SNI-based DPI** — Deep Packet Inspection reads the hostname from the TLS ClientHello and resets the connection

## Solution

A local HTTP CONNECT proxy running on `localhost` that:
1. Resolves domains via DNS-over-HTTPS (DoH) — bypasses DNS poisoning
2. Fragments the TLS ClientHello into 5-byte TCP segments — bypasses SNI inspection

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ App Process                                                      │
│                                                                  │
│  Dart HttpClient ──→ HttpOverrides.findProxy ──→ PROXY localhost │
│  Android WebView ──→ ProxyController ──→ PROXY localhost         │
│  macOS WKWebView ──→ System HTTPS proxy ──→ PROXY localhost      │
│                                                                  │
│  ┌────────────────────────────────────────┐                      │
│  │ DnsBypassService (localhost:PORT)      │                      │
│  │                                        │                      │
│  │  1. Receive CONNECT host:443           │                      │
│  │  2. Check ad blocklist → 502 if match  │                      │
│  │  3. Resolve via DoH (with fallbacks)   │                      │
│  │  4. Connect to resolved IP             │                      │
│  │  5. Fragment ClientHello + flush()     │                      │
│  │  6. Pipe data bidirectionally          │                      │
│  └────────────────────────────────────────┘                      │
└─────────────────────────────────────────────────────────────────┘
```

## DoH Resolution

### Fallback Order

The proxy tries multiple DoH servers. If one times out (5s), it moves to the next:

1. User-selected primary (e.g., `cloudflare-dns.com`)
2. `https://cloudflare-dns.com/dns-query`
3. `https://1.1.1.1/dns-query` (IP-based, skips DNS)
4. `https://dns.google/resolve`
5. `https://8.8.8.8/resolve` (IP-based, skips DNS)
6. `https://dns.nextdns.io/dns-query`

### Why IP-based Fallbacks

Domain-based DoH endpoints (e.g., `cloudflare-dns.com`) require the system DNS to resolve them first. On some devices (especially Android emulators on blocking networks), the system DNS can't resolve these hostnames either — chicken-and-egg problem. IP-based endpoints (`1.1.1.1`, `8.8.8.8`) skip DNS entirely.

### DoH API Format

All servers in the fallback list support the JSON API (`?name=domain&type=A` with `Accept: application/dns-json`). Quad9 and OpenDNS were removed because they only support RFC 8484 wire format.

### DNS Cache

Resolved IPs are cached for 5 minutes to avoid repeated DoH lookups.

## TLS Fragmentation

### How It Works

DPI systems inspect the first TCP segment of a TLS handshake for the SNI (Server Name Indication) field. By splitting the ClientHello into tiny fragments and flushing each one as a separate TCP segment, the SNI hostname spans multiple packets. Most DPI systems can't reassemble fragmented TLS records.

### Implementation

```dart
Future<void> _writeFragmented(Socket target, List<int> data) async {
  const fragmentSize = 5;
  int offset = 0;
  while (offset < data.length) {
    final end = (offset + fragmentSize).clamp(0, data.length);
    target.add(data.sublist(offset, end));
    await target.flush();  // Forces separate TCP segment
    offset = end;
  }
}
```

The `flush()` call is critical. Without it, Dart's socket layer (or Nagle's algorithm) buffers multiple `add()` calls into a single TCP packet, defeating fragmentation.

### Only First Packet

Fragmentation is only applied to the first data from the client (the TLS ClientHello). Subsequent data flows through normally without fragmentation overhead.

## Ad Blocking

### Why It's Needed

When the proxy is active, DoH resolves ALL domains — including ad/tracking networks that the ISP's DNS normally blocks. This causes ad overlays to load and cover the video player, intercepting play button clicks.

### Two-Layer Approach

1. **Proxy-level blocklist** — known ad domains get an immediate 502 response. Fast, no network request made.
2. **JS overlay remover** — injected into the WebView after page load. Uses MutationObserver to detect and remove elements that:
   - Have `position: fixed` or `absolute`
   - Have `z-index > 100`
   - Cover more than 50% of the viewport
   - Don't contain a video player element

The static blocklist handles known offenders instantly. The JS remover catches anything new.

### Updating the Blocklist

Add new domains to `lib/config/blocked_domains.dart`. Check proxy logs for new ad domains being tunneled:

```
I/flutter: CONNECT proxy: tunnel request for newadsite.com:443
```

If a new ad domain causes overlay issues, add it to the list.

## Platform Integration

### Android

- `ProxyController.setProxyOverride` with `removeImplicitRules()` routes all WebView HTTPS traffic through the proxy
- `removeImplicitRules()` is needed because Android's default proxy config bypasses localhost — without it, some requests skip the proxy
- Configured via platform channel in `MainActivity.kt`

### macOS

- System HTTPS proxy set via `networksetup` directly (no admin prompt needed)
- App sandbox disabled (`com.apple.security.app-sandbox = false`) — required for `networksetup` to execute; sandboxed apps cannot spawn system processes
- WKWebView respects system proxy settings automatically
- Proxy cleared on app exit via `applicationWillTerminate`
- `com.apple.security.network.server` entitlement required for binding a local server
- Not compatible with Mac App Store distribution (sandbox required); distributed via GitHub releases (DMG)

### Dart HTTP

- `HttpOverrides.global = DnsBypassHttpOverrides()` routes all `HttpClient` traffic through the proxy
- The DoH client itself uses `findProxy = DIRECT` to avoid circular routing

## Settings

Users can configure:
- **Proxy toggle** — enable/disable the bypass (Settings → Network)
- **DoH server** — pick from presets (Settings → Network → DNS Server)

Available presets:
| Name | URL |
|------|-----|
| Cloudflare | `https://cloudflare-dns.com/dns-query` |
| Cloudflare (IP) | `https://1.1.1.1/dns-query` |
| Google | `https://dns.google/resolve` |
| Google (IP) | `https://8.8.8.8/resolve` |
| NextDNS | `https://dns.nextdns.io/dns-query` |

## Troubleshooting

### DoH times out on all servers

Check if the device has internet at all. If DoH times out but other sites work, the ISP may be blocking DoH endpoints aggressively. Try switching to an IP-based preset (Cloudflare IP or Google IP).

### Video loads but play button doesn't work

Ad overlays are intercepting clicks. Check proxy logs for new ad domains being tunneled and add them to `_blockedDomains`. The JS overlay remover should catch most cases automatically.

### `ERR_TUNNEL_CONNECTION_FAILED` in WebView

This means a blocked domain tried to connect through the proxy and got 502'd. This is expected behavior for ad domains and doesn't affect video playback.

### Proxy works for stream list but not WebView player

Verify `setWebViewProxy` succeeded in `main.dart`. Check that `androidx.webkit` is in `build.gradle.kts` dependencies. On some older Android versions, `ProxyController` may not be supported.

### macOS WKWebView not using proxy

The system proxy must be set before the WebView loads. Verify:
1. App sandbox is disabled (`com.apple.security.app-sandbox = false`) in both `DebugProfile.entitlements` and `Release.entitlements` — sandboxed apps cannot run `networksetup`
2. Check debug console for `macOS system proxy set to 127.0.0.1:PORT` — if you see `NOT set`, the `networksetup` call failed
3. Verify manually: `networksetup -getsecurewebproxy Wi-Fi` should show `Enabled: Yes` while the app is running
