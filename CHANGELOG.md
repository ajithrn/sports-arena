# Changelog

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
