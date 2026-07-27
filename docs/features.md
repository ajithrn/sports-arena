# Features

## Home Screen
- Grid of live stream cards showing team logos, match name, league, viewer count
- Category filter bar with "All" option and per-category stream counts
- Animated pill-style category selection with visible focus state on TV/desktop
- Bouncing horizontal scroll on category bar
- Sort streams by: Most Viewers, Match Time, Name (A-Z), League
- Pull-to-refresh with debounced refresh button (5s cooldown)
- Auto-refresh with configurable interval (30s/60s/2min/5min)
- Responsive grid: 2 columns (phone), 3 columns (tablet), 4 columns (desktop/TV)
- Stream cards with hover (scale + elevation) and focus (border) states

## Stream Player
- Embedded player via WebView (Android/macOS/Windows) or iframe (Web)
- Fullscreen mode:
  - Mobile: tap icon or double-tap, back button to exit
  - Desktop: press F, Esc to exit, Cmd/Ctrl+F, or double-click
  - TV: D-pad right to focus fullscreen button, Enter to toggle
- Native window fullscreen on macOS/Windows with proper size restore
- Auto-play injection (attempts to click play button automatically)
- Streaming-app style overlay: gradient top bar with back, title, viewers, LIVE, fullscreen
- Overlay auto-hides after 5s on TV, always visible on mobile/desktop
- Viewer count and LIVE indicator in player top bar
- Player state preserved across fullscreen toggle (no reload)
- Video stops automatically when navigating back
- Native MotionEvent tap on Android TV for trusted play/pause interaction

## Ad/Popup Blocking
- **Proxy-level domain blocking**: known ad/tracking domains (tanktds.com, adclickad.com, etc.) are rejected at the CONNECT proxy with 502 — scripts never load, no bandwidth wasted
- **JS overlay remover**: MutationObserver-based script removes fixed/absolute positioned elements with high z-index that cover the viewport but aren't the video player; runs on timer + DOM mutation observer for dynamically injected overlays
- **Web**: Global JavaScript in index.html overrides window.open, blocks _blank links, auto-refocuses if a new tab steals focus
- **Android**: Navigation delegate blocks known ad domains, JS injection kills window.open and _blank links
- No sandbox on iframe (streaming server requires it absent)
- Two-layer approach: static blocklist catches known offenders fast; JS remover adapts to any new ad network by behavior (position + z-index + size)

## Networking & Reliability
- 10-second timeout on all API requests (prevents hangs on unresponsive servers)
- In-memory cache (60s streams, 300s categories) reduces redundant requests
- Custom User-Agent header identifies app version and platform to server
- Faster splash screen for returning users (800ms vs 2s for first launch)
- **DNS bypass proxy** — local CONNECT proxy resolves domains via DoH and fragments TLS ClientHello (with per-fragment flush) to bypass ISP DNS poisoning and SNI-based DPI
- **DoH fallback rotation** — tries primary server, then cycles through fallbacks (Cloudflare, Cloudflare IP, Google, Google IP, NextDNS) so blocking one DoH provider doesn't break the app
- **IP-based DoH fallbacks** — 1.1.1.1 and 8.8.8.8 skip DNS for the DoH server itself, solving the chicken-and-egg problem on devices where DoH hostnames can't be resolved
- **Configurable DoH servers** — Cloudflare, Cloudflare (IP), Google, Google (IP), NextDNS
- **Android WebView proxy** — routes embed player traffic through bypass proxy via ProxyController with `removeImplicitRules()`
- **macOS system proxy** — sets system HTTPS proxy via `networksetup` (no admin prompt, requires sandbox disabled) for WKWebView bypass
- Automatic fallback to direct connection when proxy is disabled
- 5-second DoH timeout per server (increased from 3s for reliability)

## Settings
- **Server**: View current domain, test connection, change server
- **Appearance**: Dark / Light / System theme
- **Network**: DNS proxy toggle (enabled by default), DoH server picker
- **Defaults**: Default category filter, auto-refresh toggle + interval (30s/60s/2min/5min)
- **Data & Cache**: Clear stream cache manually
- **About**: App name/version, help & tips, check for updates
- **Update**: In-app download with progress bar on Android, browser fallback on other platforms
- **Responsive layout**: 2-column (700px+) or 3-column (1000px+) grid on wide screens

## Onboarding
- Clean domain entry screen
- Validates domain by testing /api/v1/categories endpoint
- Auto-adds https:// and strips trailing slashes
- Shows error messages for invalid/unreachable domains
- **"Continue anyway" button** when validation fails — users can set domain later in settings
- Domain persisted via SharedPreferences
- Quick tips section with platform-aware usage hints

## Android TV Support
- Leanback launcher intent with proper 320x180 banner icon
- TV detection via platform channel (UiModeManager)
- Adapted layout with larger cards and 4-column grid
- Hybrid Composition WebView for proper D-pad interaction with iframe content
- Native `MotionEvent` dispatch via platform channel for trusted tap-to-play (bypasses autoplay restrictions)
- Player overlay UI: gradient top bar with back, title, viewers, LIVE, fullscreen
- Overlay auto-hides after 5s inactivity, reappears on any remote press
- D-pad focus navigation between Back and Fullscreen buttons (Left/Right to move, Enter to activate)
- Buttons invisible at rest, show dark bg + white border ring on D-pad focus
- Remote Select/Enter triggers play/pause when no button is focused
- Media keys (play/pause/stop) supported
- Aggressive autoplay with native taps + JS injection retries
- Exit confirmation dialog on home screen back button press
- JavaScript keyboard handler injected into WebView for Enter/Space play/pause

## Desktop Support (macOS & Windows)
- Native window management with customizable size (1100x750 default, 800x600 minimum)
- Keyboard shortcuts: F (fullscreen), Esc (exit fullscreen), Cmd/Ctrl+F (fullscreen), Space (play/pause)
- Stream card hover state: scale up, elevated shadow
- Stream card focus state: primary-colored border for keyboard navigation
- macOS: WKWebView with inline media playback, network entitlements for streaming
- Windows: WebView2 via webview_win_floating package (requires WebView2 Runtime), configured with writable userDataFolder for reliable operation regardless of install location
- Help & Tips screen with platform-specific instructions
- Update check downloads correct platform asset (APK/DMG/ZIP) via url_launcher
- **In-app APK download & install** on Android (phone + TV) with progress dialog and cancel support
- Release signing with persistent keystore via GitHub Actions secrets

## Category Naming
- "soccer" API category displayed as "Football"
- "football" API category displayed as "Rugby"
- Each category has a Material icon
