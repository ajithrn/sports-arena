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
│   └── domain_service.dart            # Domain persistence (SharedPreferences)
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
    ├── platform_utils.dart            # Web/Android/TV detection
    └── time_utils.dart                # Time formatting, viewer count
```

## Data Flow

```
User enters domain → DomainService saves it
                   → ApiService uses it for all HTTP calls
                   → StreamsProvider fetches streams/categories
                   → UI rebuilds via Consumer<StreamsProvider>
```

## Caching Strategy

- Streams: cached in-memory for 60 seconds
- Categories: cached in-memory for 300 seconds
- Cache is cleared on manual refresh or server change

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
- Uses lighter texture WebView mode (not Hybrid Composition)
- Larger grid (4 columns), bigger cards
- D-pad friendly layout
- Leanback launcher intent in AndroidManifest

### macOS
- Player uses `webview_flutter_wkwebview` (WKWebView)
- `WebKitWebViewControllerCreationParams` with `allowsInlineMediaPlayback: true`
- `mediaTypesRequiringUserAction` set to empty for autoplay
- App sandbox entitlements with `com.apple.security.network.client`
- Native window fullscreen via `window_manager`
- Keyboard shortcuts: F, Esc, Cmd+F

### Windows
- Player uses `webview_win_floating` (WebView2, implements webview_flutter API)
- Requires WebView2 Runtime (pre-installed on Windows 11, usually on Windows 10)
- Native window fullscreen via `window_manager`
- Keyboard shortcuts: F, Esc, Ctrl+F
