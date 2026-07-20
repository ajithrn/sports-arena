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
- Embedded player via WebView (Android) or iframe (Web)
- Fullscreen mode (tap icon or double-tap, back button to exit)
- Auto-play injection (attempts to click play button automatically)
- Info bar showing league, category, and LIVE badge
- Viewer count display

## Ad/Popup Blocking
- **Web**: Global JavaScript in index.html overrides window.open, blocks _blank links, auto-refocuses if a new tab steals focus
- **Android**: Navigation delegate blocks known ad domains, JS injection kills window.open and _blank links
- No sandbox on iframe (streaming server requires it absent)

## Settings
- **Server**: View current domain, test connection, change server
- **Appearance**: Dark / Light / System theme
- **Defaults**: Default category filter, auto-refresh toggle + interval (30s/60s/2min/5min)
- **Data & Cache**: Clear stream cache manually
- **About**: App name and version

## Onboarding
- Clean domain entry screen
- Validates domain by testing /api/v1/categories endpoint
- Auto-adds https:// and strips trailing slashes
- Shows error messages for invalid/unreachable domains
- Domain persisted via SharedPreferences

## Android TV Support
- Leanback launcher intent (shows on TV home screen)
- TV detection via platform channel (UiModeManager)
- Adapted layout with larger cards and 4-column grid
- Lighter WebView mode for TV (texture instead of Hybrid Composition)
- D-pad navigation support

## Category Naming
- "soccer" API category displayed as "Football"
- "football" API category displayed as "Rugby"
- Each category has a Material icon
