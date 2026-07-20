# Development Setup

## Prerequisites

- Flutter SDK 3.12+
- Android Studio (for Android builds + emulators)
- Xcode 14+ (for macOS builds)
- Visual Studio 2019+ with C++ desktop workload (for Windows builds)
- Chrome/Chromium (for web builds)

## Install

```bash
cd sports_arena
flutter pub get
```

## Run

```bash
# Web
flutter run -d chrome

# macOS
flutter run -d macos

# Windows
flutter run -d windows

# Android phone (emulator or device)
flutter run -d emulator-5554

# List available devices
flutter devices
```

## Emulators

Create emulators via Android Studio Device Manager, or CLI:

```bash
# Phone
~/Library/Android/sdk/emulator/emulator -avd Pixel_7_API34 &

# Android TV
~/Library/Android/sdk/emulator/emulator -avd Android_TV_API31 &
```

## Project Architecture

- **State management:** Provider (ChangeNotifier)
- **HTTP:** `package:http` with in-memory caching
- **Player:** WebView on Android/macOS/Windows, iframe on Web (conditional import)
- **Window management:** `window_manager` for desktop fullscreen/sizing
- **Storage:** SharedPreferences for domain + settings
- **TV detection:** Platform channel (UiModeManager)

## Key Files

| File | Purpose |
|------|---------|
| `lib/config/app_config.dart` | API paths, cache durations, storage keys, app version |
| `lib/main.dart` | Entry point, provider setup, desktop window init |
| `lib/services/domain_service.dart` | User's server domain (stored locally) |
| `lib/services/api_service.dart` | HTTP client with cache |
| `lib/screens/player/player_widget.dart` | Conditional import (web vs native) |
| `lib/screens/player/player_widget_native.dart` | Platform-aware WebView (Android/macOS/Windows) |
| `lib/screens/player/player_screen.dart` | Player with fullscreen, keyboard shortcuts |
| `lib/screens/settings/help_screen.dart` | Help & tips page |
| `macos/Runner/Release.entitlements` | macOS sandbox + network permissions |
| `windows/runner/main.cpp` | Windows app entry, window title |
| `android/app/src/main/AndroidManifest.xml` | TV leanback + permissions |

## Adding a New Category Icon

Edit `lib/models/category_model.dart` — add the slug to both `_getDisplayName()` and `_getIcon()`.

## Regenerating the App Icon

```bash
# Edit assets/icon/app_icon.png and app_icon_foreground.png, then:
dart run flutter_launcher_icons
```
