# Architecture

## Tech Stack

- **Framework**: Flutter 3.38+ (Dart)
- **State Management**: Provider (ChangeNotifier pattern)
- **HTTP**: `http` package
- **Player**: WebView (Android), iframe HtmlElementView (Web)
- **Storage**: SharedPreferences for domain and settings
- **Platforms**: Android (mobile + TV), Web

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
│   ├── onboarding/onboarding_screen.dart  # Domain entry + validation
│   ├── home/home_screen.dart          # Category bar + stream grid
│   ├── player/
│   │   ├── player_screen.dart         # Player page with fullscreen toggle
│   │   ├── player_widget.dart         # Conditional export (web vs native)
│   │   ├── player_widget_native.dart  # Android WebView player
│   │   └── player_widget_web.dart     # Web iframe player
│   └── settings/settings_screen.dart  # Settings page
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
