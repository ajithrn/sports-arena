# Architecture

## Tech Stack

- **Framework**: Flutter 3.44+ (Dart)
- **State Management**: Provider (ChangeNotifier pattern)
- **HTTP**: `http` package
- **Player**: WebView (Android/macOS/Windows), iframe HtmlElementView (Web)
- **Window Management**: `window_manager` (desktop fullscreen/sizing)
- **Storage**: SharedPreferences for domain and settings
- **Platforms**: Android (mobile + TV), macOS, Windows, Web

## Project Structure

```
lib/
├── main.dart                          # Entry point, provider setup
├── app.dart                           # MaterialApp with theming
├── config/
│   └── app_config.dart                # API paths, cache durations, storage keys
├── models/
│   ├── stream_model.dart              # SportStream + TeamInfo
│   └── category_model.dart            # SportCategory with icons
├── services/
│   ├── api_service.dart               # HTTP client with in-memory cache
│   ├── dns_bypass_service.dart        # CONNECT proxy with DoH + TLS fragmentation
│   ├── domain_service.dart            # Domain persistence (SharedPreferences)
│   ├── apk_download_service.dart      # APK download & install for Android updates
│   └── update_service.dart            # GitHub release version checker
├── providers/
│   ├── streams_provider.dart          # Stream list, filtering, sorting
│   └── settings_provider.dart         # Theme, default category, auto-refresh
├── screens/
│   ├── splash/splash_screen.dart      # Animated splash, checks if domain is set
│   ├── onboarding/onboarding_screen.dart  # Domain entry + validation + quick tips
│   ├── home/home_screen.dart          # Category bar + stream grid
│   ├── player/
│   │   ├── player_screen.dart         # Player page with fullscreen toggle + keyboard shortcuts
│   │   ├── player_widget.dart         # Conditional export (web vs native)
│   │   ├── player_widget_native.dart  # Android/macOS/Windows WebView player
│   │   └── player_widget_web.dart     # Web iframe player
│   └── settings/
│       ├── settings_screen.dart       # Settings page
│       └── help_screen.dart           # Help & tips page
├── widgets/
│   ├── stream_card.dart               # Stream card with teams, badges
│   ├── category_chip.dart             # Category filter chip (unused, replaced)
│   └── loading_grid.dart              # Shimmer loading skeleton
└── utils/
    ├── platform_utils.dart            # Web/Android/Desktop/TV detection
    ├── error_utils.dart               # User-friendly error mapping (AppError)
    └── time_utils.dart                # Time formatting, viewer count
```

## Data Flow

```
User enters domain → DomainService saves it
                   → ApiService uses it for all HTTP calls
                   → StreamsProvider fetches streams/categories
                   → UI rebuilds via Consumer<StreamsProvider>
```

## DNS Bypass Flow

```
App starts → DnsBypassService starts CONNECT proxy on localhost
           → HttpOverrides.global routes all Dart HTTP through it
           → Android: ProxyController (with removeImplicitRules) routes WebView through it
           → macOS: system proxy set via networksetup
           → Windows: user-level WinINET proxy set via registry (WebView2 respects it)

When a request arrives at the proxy:
  1. Client sends CONNECT example.com:443
  2. Proxy checks domain against ad blocklist → if blocked, return 502 immediately
  3. Proxy resolves domain via DoH (tries primary, then fallbacks):
     - Primary: user-selected server (e.g., cloudflare-dns.com)
     - Fallbacks: 1.1.1.1, dns.google, 8.8.8.8, dns.nextdns.io
     - IP-based endpoints skip DNS for the DoH server itself (avoids chicken-and-egg)
  4. Proxy connects to the DoH-resolved IP on port 443
  5. Proxy fragments the TLS ClientHello into 5-byte segments with flush()
     after each fragment (forces separate TCP segments, bypasses SNI-based DPI)
  6. Proxy pipes all data bidirectionally (transparent tunnel)
  7. Client does TLS handshake through tunnel with correct SNI
  8. ISP can't read SNI from fragmented packets → connection succeeds

Ad overlay prevention (two layers):
  - Proxy blocklist: known ad domains get 502'd before connecting (fast, saves bandwidth)
  - JS overlay remover: MutationObserver strips high-z-index overlays covering the player
    (catches new/unknown ad domains that bypass the static blocklist)
```

## Caching Strategy

- Streams: cached in-memory for 60 seconds
- Categories: cached in-memory for 300 seconds
- Cache is cleared on manual refresh or server change
- All API requests have a 10-second timeout
- Custom User-Agent header identifies app version and platform
- Auto-refresh timer runs in background (configurable interval)
- Manual refresh has 5-second debounce cooldown

## Platform-Specific Behavior

### Web
- Player uses `HtmlElementView` with an iframe
- No sandbox attribute (server requires it absent)
- Global JS in index.html blocks popups/new tabs
- Aggressive refocus when tab loses visibility

### Android Mobile
- Player uses `webview_flutter` with Hybrid Composition
- `setMediaPlaybackRequiresUserGesture(false)` for autoplay
- Navigation guard blocks known ad domains
- JS injection blocks window.open and _blank links
- Full gesture recognizer set for touch passthrough

### Android TV
- Detected via platform channel (`UiModeManager`)
- Hybrid Composition WebView for proper D-pad interaction with iframe content
- Native `MotionEvent` dispatch via `tapWebViewCenter` platform channel method (finds WebView in view hierarchy, dispatches trusted touch at center)
- `HardwareKeyboard` handler intercepts Enter/Select for native tap, D-pad arrows for manual focus movement between buttons
- Player overlay auto-hides after 5s, reappears on any remote key press
- Focus management: explicit `FocusNode` per button, `OrderedTraversalPolicy` for predictable left/right navigation
- JS keyboard handler injected into WebView page (Enter/Space triggers play/pause when WebView has platform focus)
- Larger grid (4 columns), bigger cards
- D-pad navigation with visible focus highlights (dark bg + white border on focus)
- Leanback launcher with proper 320x180 banner icon
- Aggressive autoplay: native taps at 2s/4s/7s + JS touch event simulation
- Exit confirmation on home screen back press

### macOS
- Player uses `webview_flutter_wkwebview` (WKWebView)
- `WebKitWebViewControllerCreationParams` with `allowsInlineMediaPlayback: true`
- `mediaTypesRequiringUserAction` set to empty for autoplay
- App sandbox disabled (`com.apple.security.app-sandbox = false`) — required for `networksetup` to execute
- `com.apple.security.network.client` and `com.apple.security.network.server` entitlements
- System proxy set via `networksetup` directly (no admin prompt) for WKWebView DNS bypass
- Proxy cleared on app exit via `applicationWillTerminate`
- Native window fullscreen via `window_manager`
- Keyboard shortcuts: F, Esc, Cmd+F

### Windows
- Player uses `webview_win_floating` (WebView2, implements webview_flutter API)
- `WindowsWebViewControllerCreationParams` with writable `userDataFolder` (`getApplicationSupportDirectory()/webview2_data`) — WebView2 cannot create data folder in read-only install locations
- Floating native window limitation: WebView2 renders on top of Flutter widgets, so Flutter cannot overlay controls above it
- Player screen uses Column layout (solid header bar above WebView) instead of Stack overlay
- User-level WinINET proxy set via registry (`HKCU\...\Internet Settings`) — routes WebView2 traffic through the CONNECT proxy for DoH DNS bypass (no admin required)
- Proxy auto-cleared on app exit (`AppLifecycleListener`) and on service stop
- Requires WebView2 Runtime (pre-installed on Windows 11, usually on Windows 10)
- Native window fullscreen via `window_manager`
- Keyboard shortcuts: F, Esc, Ctrl+F
