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
- Native window fullscreen on macOS/Windows with proper size restore
- Auto-play injection (attempts to click play button automatically)
- Info bar showing league, category, and LIVE badge
- Viewer count display
- Player state preserved across fullscreen toggle (no reload)
- Video stops automatically when navigating back

## Ad/Popup Blocking
- **Web**: Global JavaScript in index.html overrides window.open, blocks _blank links, auto-refocuses if a new tab steals focus
- **Android**: Navigation delegate blocks known ad domains, JS injection kills window.open and _blank links
- No sandbox on iframe (streaming server requires it absent)

## Networking & Reliability
- 10-second timeout on all API requests (prevents hangs on unresponsive servers)
- In-memory cache (60s streams, 300s categories) reduces redundant requests
- Custom User-Agent header identifies app version and platform to server
- Faster splash screen for returning users (800ms vs 2s for first launch)

## Settings
- **Server**: View current domain, test connection, change server
- **Appearance**: Dark / Light / System theme
- **Defaults**: Default category filter, auto-refresh toggle + interval (30s/60s/2min/5min)
- **Data & Cache**: Clear stream cache manually
- **About**: App name/version, help & tips, check for updates

## Onboarding
- Clean domain entry screen
- Validates domain by testing /api/v1/categories endpoint
- Auto-adds https:// and strips trailing slashes
- Shows error messages for invalid/unreachable domains
- Domain persisted via SharedPreferences
- Quick tips section with platform-aware usage hints

## Android TV Support
- Leanback launcher intent with proper 320x180 banner icon
- TV detection via platform channel (UiModeManager)
- Adapted layout with larger cards and 4-column grid
- Hybrid Composition WebView for proper D-pad interaction with iframe content
- D-pad navigation with visible focus highlights (glow + border)
- Remote Select/Enter triggers play, media keys supported
- Aggressive autoplay with multiple retry attempts

## Desktop Support (macOS & Windows)
- Native window management with customizable size (1100x750 default, 800x600 minimum)
- Keyboard shortcuts: F (fullscreen), Esc (exit fullscreen), Cmd/Ctrl+F (fullscreen), Space (play/pause)
- Stream card hover state: scale up, elevated shadow
- Stream card focus state: primary-colored border for keyboard navigation
- macOS: WKWebView with inline media playback, network entitlements for streaming
- Windows: WebView2 via webview_win_floating package (requires WebView2 Runtime)
- Help & Tips screen with platform-specific instructions
- Update check downloads correct platform asset (APK/DMG/ZIP) via url_launcher

## Category Naming
- "soccer" API category displayed as "Football"
- "football" API category displayed as "Rugby"
- Each category has a Material icon
