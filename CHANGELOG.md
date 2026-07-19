# Changelog

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
