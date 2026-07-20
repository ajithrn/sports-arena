# Features

## Home Screen
- Grid of live stream cards showing team logos, match name, league, viewer count
- Category filter bar with "All" option and per-category stream counts
- Animated pill-style category selection
- Bouncing horizontal scroll on category bar
- Sort streams by: Most Viewers, Match Time, Name (A-Z), League
- Pull-to-refresh
- Responsive grid: 2 columns (phone), 3 columns (tablet), 4 columns (desktop/TV)

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
- Leanback launcher intent (shows on TV home screen)
- TV detection via platform channel (UiModeManager)
- Adapted layout with larger cards and 4-column grid
- Lighter WebView mode for TV (texture instead of Hybrid Composition)
- D-pad navigation support

## Desktop Support (macOS & Windows)
- Native window management with customizable size (1100x750 default, 800x600 minimum)
- Keyboard shortcuts: F (fullscreen), Esc (exit fullscreen), Cmd/Ctrl+F (fullscreen)
- macOS: WKWebView with inline media playback, network entitlements for streaming
- Windows: WebView2 via webview_win_floating package (requires WebView2 Runtime)
- Help & Tips screen with platform-specific instructions

## Category Naming
- "soccer" API category displayed as "Football"
- "football" API category displayed as "Rugby"
- Each category has a Material icon
