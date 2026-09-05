# Changelog

## 1.5.0 - 2026-07-29

### Added
- **Multi-quality source selection** — streams that offer multiple qualities now show a quality label (e.g. 1080p, 4K) in the player; tapping it opens a picker to switch sources
- **Default quality preference** — new setting under Defaults to choose the preferred playback quality (Highest available, 4K, 1080p, 720p, 540p); the player auto-selects the closest match, defaulting to 1080p

### Fixed
- **Embed player not loading on any platform** — the API returns playback URLs in a `sources` array from the stream detail endpoint, but the app read a non-existent `embed_url` field and never fetched the detail, so the player loaded an empty URL. The player now fetches the stream detail and resolves a real source before loading
- Player now shows a loading indicator while resolving the source and a retryable error state when no playable source is found

### Changed
- In-player quality control uses a plain-text resolution label that blends with the other overlay info (viewers / LIVE) instead of a boxed button
- TV D-pad navigation extended to include the quality control (Back ↔ Play/Pause ↔ Quality ↔ Fullscreen)

## 1.4.2 - 2026-07-29

### Changed
- **Desktop player overlay auto-hides** — overlay now fades out after 5 seconds of inactivity on macOS/Linux (matching TV behavior)
- Mouse movement or click anywhere on the player reveals the overlay
- Removed play/pause button from desktop overlay (non-functional for initial playback due to browser trust requirements)
- Replaced overlay reveal button with a minimal three-dots icon (no background) in top-left corner

## 1.4.1 - 2026-07-27

### Added
- **Windows user proxy** — sets WinINET registry proxy so WebView2 routes through DoH bypass (no admin required); auto-cleans on app exit
- **Play/Pause button in player overlay** — fallback button in header bar beside fullscreen for Android TV when embed play button is unreliable via D-pad

### Changed
- Windows player screen uses Column layout (header above WebView) instead of Stack overlay — webview_win_floating renders native window on top of Flutter so overlays are invisible
- Windows WebView2 initialized with `WindowsWebViewControllerCreationParams` and writable `userDataFolder` for reliable operation from any install location
- Player widget controller initialization is now async to support platform-specific setup (Windows path_provider)
- D-pad focus chain on TV updated: Back ↔ Play/Pause ↔ Fullscreen (play/pause focused first on initial D-pad press)

### Fixed
- **Windows player not loading (`ERR_NAME_NOT_RESOLVED`)** — WebView2 was using system DNS which ISP blocks; now routes through local CONNECT proxy via user-level WinINET proxy setting
- **Windows player header/controls invisible** — webview_win_floating native window covered Flutter overlay; switched to Column layout with solid header bar above WebView
- **Windows WebView2 failing silently** — no writable `userDataFolder` configured; now uses `getApplicationSupportDirectory()/webview2_data`

## 1.4.0 - 2026-07-21

### Added
- **DNS bypass proxy** — local CONNECT proxy with DoH resolution + TLS ClientHello fragmentation to bypass ISP blocking (see [docs/proxy.md](docs/proxy.md))
- **DoH fallback rotation** — automatically tries multiple DoH providers if one is blocked/slow
- **Proxy-level ad blocking** — blocks known ad/tracking domains at proxy layer
- **JS overlay remover** — strips ad overlays covering the video player via MutationObserver
- **Android WebView proxy** — ProxyController routes WebView traffic through bypass proxy
- **macOS system proxy** — sets system HTTPS proxy for WKWebView bypass
- **Configurable DoH servers** — Cloudflare, Cloudflare (IP), Google, Google (IP), NextDNS
- **Improved error messages** — user-friendly messages with short error codes
- **Onboarding skip** — proceed even if domain validation fails
- **Responsive settings layout** — 2/3 column grid on wide screens

### Changed
- Update dialog shows commit message under "What's new"
- APK download uses external cache directory, improved permission flow
- Settings UI with Network section (DNS proxy toggle, server picker)
- Settings wide layout uses 2 columns (removed 3-col), cards stretch to equal row height
- macOS entitlements — disabled app sandbox for both debug and release (required for system proxy)
- macOS proxy helper — calls `networksetup` directly instead of via osascript with admin privileges
- DoH timeout increased to 5s for reliability

### Fixed
- TLS fragmentation not bypassing DPI — added `socket.flush()` per fragment for real TCP segment separation
- DoH failing on Android emulator — added IP-based fallbacks (1.1.1.1, 8.8.8.8) that skip DNS
- Ad overlays blocking video when proxy enabled — DoH resolved ad domains that ISP normally blocked
- macOS system proxy not setting — removed osascript/admin prompt, use direct `networksetup` (works without admin)
- macOS WKWebView blank screen — disabled app sandbox so `networksetup` can execute
- Android APK install permission denied (FileProvider + external cache)
- Added `network.server` entitlement for macOS, `androidx.webkit` for Android
- Settings card heights uneven in wide layout — use `IntrinsicHeight` + `Expanded` for equal row heights
- Stream card horizontal overflow on small screens — team logos now flexible
- Stream card bottom overflow — adjusted info section height

## 1.3.4 - 2026-07-21

### Fixed
- **Double-tap fullscreen on mobile only goes portrait** — double-tap was triggering the WebView's native HTML5 fullscreen (portrait-only) instead of Flutter's fullscreen with landscape orientation and immersive mode
- Double-tap to enter/exit fullscreen now correctly forces landscape + immersive sticky mode (same as the fullscreen button)

### Changed
- `PlayerWidget` now accepts `onDoubleTap` callback, used by `PlayerScreen` to handle fullscreen toggle at the Flutter level
- Added transparent gesture overlay on Android WebView to intercept double-tap before it reaches the iframe
- Updated dependencies: `intl` 0.19→0.20.3, `permission_handler` 11.4→12.0.3, `window_manager` 0.4.3→0.5.2

## 1.3.3 - 2026-07-21

### Added
- **In-app APK download & install on Android** — tapping "Download" now downloads the APK with a progress dialog and triggers installation directly, no browser needed
- **Android TV update support** — in-app download works without requiring a browser (which Android TV doesn't have)
- **Release signing via GitHub Actions** — workflow decodes keystore from secrets, ensuring every release APK is signed with the same key
- `ApkDownloadService` with download progress, cancel support, and permission handling
- `REQUEST_INSTALL_PACKAGES` permission for triggering APK installs
- `FileProvider` configuration for sharing downloaded APK with system installer
- `dio`, `open_filex`, `path_provider`, `permission_handler` dependencies

### Changed
- Update flow on Android now downloads & installs in-app instead of opening browser
- Release build signing moved from debug keystore to a persistent release keystore
- `build.gradle.kts` loads signing config from `key.properties` (falls back to debug if missing)
- GitHub Actions workflow creates `key.properties` from repository secrets during build

### Fixed
- **Users forced to uninstall before updating** — caused by different signing keys on each CI build (debug keystore is unique per machine)
- **Download button doing nothing on Android TV** — no browser available to handle the URL
- **Download button unreliable on Android phones** — depended on browser downloading APK correctly

### Technical
- `android/key.properties` gitignored (contains signing secrets)
- `android/app/src/main/res/xml/file_paths.xml` added for FileProvider
- GitHub secrets required: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`

## 1.3.2 - 2026-07-21

### Added
- **Native tap-to-play on Android TV** — uses platform channel to dispatch a real `MotionEvent` to the WebView, satisfying browser autoplay policies that reject synthetic JS events
- **Player overlay UI** — streaming-app style top bar with gradient fade, auto-hides after 5s inactivity on TV, reappears on any remote press
- **D-pad focus navigation** — manual focus management between Back and Fullscreen buttons via `HardwareKeyboard` handler (Left/Right to move, Enter to activate)
- **Exit confirmation** — "Exit App" dialog when pressing back on the home screen (prevents accidental app exit on TV remotes)
- **TV keyboard handler injection** — injects JavaScript keydown listener into WebView page for Enter/Space play/pause when WebView has platform focus
- Viewer count moved to player bottom bar (beside LIVE badge)

### Changed
- Player screen redesigned: full-screen video with translucent gradient overlay (no solid bars)
- LIVE indicator made subtle (red dot + text, no background box)
- Buttons invisible at rest, show dark circular bg + white border only on D-pad focus
- Top bar shows: Back button, stream name, viewer count, LIVE indicator, fullscreen button
- No bottom bar — cleaner full-screen video experience
- `simulateCenterClick` now tries native `MotionEvent` first (trusted), falls back to JS `video.play()`
- Autoplay injection now dispatches touch events (not just `.click()`) for better embed compatibility
- `HardwareKeyboard` handler no longer blocks D-pad arrows from reaching buttons
- Overlay auto-hide is TV-only; desktop/mobile always show the top bar

### Fixed
- **D-pad unable to interact with embedded video player** — fundamental issue where Flutter intercepted all key events before they reached the WebView platform view
- **Buttons not focusable after playing video** — WebView platform view grabbed Android focus; now handled by manual focus management
- **Fullscreen button unreachable via D-pad** — Flutter's focus traversal couldn't cross non-focusable text widgets; replaced with explicit left/right focus switching
- **Accidental back navigation** — removed autofocus from buttons, nothing highlighted until user moves D-pad

### Technical
- Added `tapWebViewCenter` method to `MainActivity.kt` — finds WebView in view hierarchy and dispatches `MotionEvent.ACTION_DOWN`/`ACTION_UP` at center
- `PlayerWidgetState.simulateCenterClick()` now async, calls platform channel first
- `_injectTvKeyboardHandler()` makes `document.body` focusable and listens for Enter/Space
- Explicit `FocusNode` instances for back/fullscreen buttons with manual `requestFocus()` management
- `OrderedTraversalPolicy` with `NumericFocusOrder` for predictable D-pad traversal

## 1.3.1 - 2026-07-20

### Added
- Connection error banner on home screen when server is unreachable
- "Updated Xs ago" tooltip on refresh button
- Auto-refresh timer that respects settings interval (30s/60s/2min/5min)
- Refresh button debounce (5s cooldown prevents spamming)
- Custom User-Agent header on all API requests (identifies app version + platform)
- `PlatformUtils.isDesktop` centralized helper

### Changed
- Splash screen loads faster for returning users (800ms vs 2s)
- All API calls now have 10-second timeout (prevents infinite hangs)
- Inline desktop platform checks replaced with `PlatformUtils.isDesktop`
- Auto-refresh timer restarts when returning from settings
- Android TV uses Hybrid Composition WebView (fixes D-pad interaction with iframe player)
- TV banner icon updated to proper 320x180 Leanback banner
- Update download opens in system browser via `url_launcher`
- Update service picks correct platform asset (APK/DMG/ZIP)

### Fixed
- Android TV D-pad unable to click play button inside iframe (texture mode → Hybrid Composition)
- Android TV showing square icon instead of wide banner in launcher
- Update "Download" button not actually downloading anything
- Dead code: removed unused `DomainService.validateDomain()` method
- Removed unused `foundation.dart` imports across multiple files

### Code Quality
- Centralized platform detection in `PlatformUtils` (isWeb, isAndroid, isDesktop, isTv)
- Removed dead/misleading code
- Consistent import patterns

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
