# Sports Arena

Live sports streaming app built with Flutter. Supports Android (phone + TV) and Web.

## Features

- Browse live sports streams by category (Football, Basketball, Hockey, Combat, Baseball, Rugby, Racing, Tennis, Cricket)
- Stream playback via embedded player
- Category filtering with stream counts
- Sort streams by viewers, match time, name, or league
- Dark/Light/System theme support
- Configurable streaming server (entered during onboarding, changeable in settings)
- Auto-refresh with configurable interval
- Popup/new-tab blocking for ad suppression
- Android TV support with D-pad navigation and Leanback launcher
- Fullscreen player with back-button exit
- Pull-to-refresh on stream list

## Getting Started

### Prerequisites

- Flutter SDK 3.12+
- Android Studio (for Android builds)
- Chrome (for web builds)

### Install dependencies

```bash
cd sports_arena
flutter pub get
```

### Run

```bash
# Web
flutter run -d chrome

# Android (with device/emulator connected)
flutter run -d <device_id>
```

### Build

```bash
# Release APK (works on both phone and Android TV)
flutter build apk --release

# Web
flutter build web
```

The APK is output to `build/app/outputs/flutter-apk/app-release.apk`.

## Project Structure

```
lib/
├── config/app_config.dart        # App constants, API paths, cache durations
├── models/
│   ├── stream_model.dart         # SportStream data model
│   └── category_model.dart       # Category with display name and icon
├── services/
│   ├── api_service.dart          # HTTP client with caching
│   └── domain_service.dart       # User's server domain persistence
├── providers/
│   ├── streams_provider.dart     # Stream list state + filtering/sorting
│   └── settings_provider.dart    # Theme, defaults, auto-refresh prefs
├── screens/
│   ├── splash/                   # Splash screen with domain check
│   ├── onboarding/               # Server domain entry
│   ├── home/                     # Category bar + stream grid
│   ├── player/                   # WebView player (conditional web/native)
│   └── settings/                 # Settings page
├── widgets/                      # StreamCard, CategoryChip, LoadingGrid
├── utils/                        # Platform detection, time formatting
├── app.dart                      # MaterialApp with theme
└── main.dart                     # Entry point with providers
```

## Configuration

No API URLs are hardcoded. The user enters their streaming server domain during first launch. The domain is stored locally via SharedPreferences and can be changed anytime from Settings > Server > Change.

The API expects endpoints at:
- `GET /api/v1/categories`
- `GET /api/v1/streams`
- `GET /api/v1/streams/{stream_key}`
- `/embed/{category}/{stream_key}` (player embed)

## Android TV

The app includes a Leanback launcher intent and declares `android.software.leanback` (not required) so it appears on Android TV home screens. TV mode is auto-detected and adjusts the layout (larger grid, D-pad focus).

## License

Private project.
