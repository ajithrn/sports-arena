# Changelog

## 1.3.0 - 2026-07-20

### Added
- **macOS desktop support** — native app with .dmg installer
- **Windows desktop support** — native app with .zip portable bundle
- **Linux desktop support** — native app via flutter build linux
- Desktop keyboard shortcuts: F (fullscreen toggle), Esc (exit fullscreen), Cmd/Ctrl+F (fullscreen), Space (play/pause)
- Android TV remote support: Select/Enter to play/pause, D-pad up/down for fullscreen toggle
- Android TV proper banner icon (320x180dp) for Leanback launcher
- Help & Tips screen accessible from Settings
- Quick tips section on onboarding screen (platform-aware)
- `window_manager` integration for native desktop window fullscreen
- `url_launcher` for opening update downloads in system browser

### Changed
- CI/CD workflow now builds Android APK, macOS DMG, and Windows ZIP in parallel
- Player widget refactored to be platform-aware (WKWebView on macOS, WebView2 on Windows, Android WebView on Android)
- Fullscreen on desktop uses native window fullscreen with proper size save/restore
- Fullscreen hint shows keyboard instructions on desktop, touch instructions on mobile
- Player preserved across fullscreen toggle (no reload) via GlobalKey
- Category bar tabs now use InkWell (focusable) instead of GestureDetector for D-pad navigation
- Settings theme selector uses ListTile + Radio instead of RadioListTile to prevent focus trap
- Stream cards now have visible hover (scale + elevation) and focus (border) states for desktop/TV
- Update service now picks correct platform asset (APK/DMG/ZIP) automatically
- Autoplay injection broadened with more selectors and retry attempts
- Version bumped from 1.2.0 to 1.3.0 across pubspec, app config, and README

### Fixed
- "UnimplementedError: opaque is not implemented on macOS" crash in player
- Video continuing to play in background after navigating back (all platforms)
- Fullscreen exit not restoring correct window size on desktop
- Hardcoded version (1.1.2) in app_config.dart not matching pubspec version
- macOS CI build failing due to `Info.plist` excluded by `.gitignore`
- Android TV D-pad not selecting category filters (GestureDetector replaced with focusable InkWell)
- Android TV D-pad stuck in loop on settings theme selector (RadioListTile focus trap)
- Android TV remote Select/Enter button not triggering play in WebView player
- Android TV showing square icon instead of proper banner in launcher
- Update download button not actually downloading (now opens in browser)
- Player appearing stuck/loading indefinitely (added 8s safety timeout)

## 1.2.0 - 2026-07-20

### Added
- Fullscreen exit hint overlay (3-second pill: "Double-tap or press back to exit fullscreen")
- Haptic feedback on category selection (lightImpact) and fullscreen toggle (mediumImpact)
- Semantics/accessibility labels on category tabs, stream cards, and fullscreen player
- Improved empty state with category-aware messaging and actionable buttons
- Loading spinner on refresh button while streams are loading
- Autofocus on domain text field for Android TV compatibility

### Changed
- Category display order: Football, Cricket, Racing, Tennis, Basketball, Hockey, Combat, Baseball, Rugby
- Stream card badge and player info bar now show display names instead of raw API slugs
- Migrated deprecated `RadioListTile` groupValue/onChanged to `RadioGroup` widget
- Replaced deprecated `.withOpacity()` calls with `.withValues(alpha:)` in category chips
- Replaced `__`/`___` unused params with `_` (Dart 3 wildcard syntax)
- Added `mounted` guard after async gap in splash screen navigation

### Fixed
- Emulator GPU acceleration disabled causing frozen input (config: `hw.gpu.enabled=yes`, `hw.gpu.mode=host`)
- Emulator snapshot corruption causing unresponsive touch (cleared snapshots, increased RAM to 4GB)
- Android TV emulator keyboard input not working (`hw.keyboard=yes`)
- All `flutter analyze` info-level deprecation warnings resolved (0 issues)

## 1.1.0 - 2025-07-20

### Added
- Category sorting (by viewers, match time, name, league)
- "All" tab in category bar for quick filter reset
- Settings page with server management, theme, defaults, cache control
- Fullscreen player mode with back-button exit
- Auto-play injection for stream player
- Popup/new-tab blocking (web: global JS blocker, Android: navigation guard)
- Android TV support (Leanback launcher, D-pad detection, adapted layout)
- Custom app icon (sports whistle)
- Onboarding flow with server domain validation

### Changed
- Renamed "Soccer" category to "Football"
- Renamed "Football" category to "Rugby"
- Category bar redesigned with animated pills, bounce scroll, and stream counts
- Sort control moved to app bar icon
- Removed "X streams live" text from home screen
- Player uses Hybrid Composition on Android for proper touch handling

### Fixed
- WebView touch events not passing through to embedded player
- Iframe sandbox issue causing "Embed without sandbox" error
- App icon updated from default Flutter icon

## 1.0.0 - 2025-07-20

### Initial Release
- Browse live sports streams
- Category filtering
- Stream playback via WebView/iframe embed
- Dark theme
- Responsive grid layout
- Basic caching (60s streams, 300s categories)
- Web and Android platform support
