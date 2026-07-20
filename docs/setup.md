# Development Setup

## Prerequisites

- Flutter SDK 3.12+
- Android Studio (for Android builds and emulators)
- Xcode 14+ (for macOS builds)
- Visual Studio 2019+ with "Desktop development with C++" workload (for Windows builds)
- Chrome/Chromium (for web development)
- Java 17+ (bundled with Android Studio)

## Getting Started

```bash
cd sports_arena
flutter pub get
```

## Running

```bash
# Web (fastest for development)
flutter run -d chrome

# macOS
flutter run -d macos

# Windows
flutter run -d windows

# Android device/emulator
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
flutter run -d <device_id>

# List available devices
flutter devices
```

## Building

### Release APK (Phone + TV)
```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### macOS
```bash
flutter build macos --release
```
Output: `build/macos/Build/Products/Release/Sports Arena.app`

### Windows
```bash
flutter build windows --release
```
Output: `build/windows/x64/runner/Release/`

### Web
```bash
flutter build web
```
Output: `build/web/`

## Emulators

### Create Phone Emulator
```bash
~/Library/Android/sdk/cmdline-tools/latest/bin/sdkmanager "system-images;android-34;google_apis_playstore;arm64-v8a"
echo "no" | ~/Library/Android/sdk/cmdline-tools/latest/bin/avdmanager create avd -n "Pixel_7_API34" -k "system-images;android-34;google_apis_playstore;arm64-v8a" -d "pixel_7"
```

### Create Android TV Emulator
```bash
~/Library/Android/sdk/cmdline-tools/latest/bin/sdkmanager "system-images;android-31;google-tv;arm64-v8a"
echo "no" | ~/Library/Android/sdk/cmdline-tools/latest/bin/avdmanager create avd -n "Android_TV_API31" -k "system-images;android-31;google-tv;arm64-v8a" -d "tv_1080p"
```

### Launch Emulator
```bash
~/Library/Android/sdk/emulator/emulator -avd Pixel_7_API34 &
# or
~/Library/Android/sdk/emulator/emulator -avd Android_TV_API31 &
```

## Sideloading on Fire Stick / Android TV

```bash
# Enable Developer Options and ADB debugging on the TV
# Connect via WiFi:
adb connect <tv-ip-address>:5555

# Install
adb install build/app/outputs/flutter-apk/app-release.apk
```

## Updating the App Icon

The app icon is generated from the Material Icons sports whistle glyph.

```bash
# Regenerate icon (requires ImageMagick)
cd assets/icon
magick -size 1024x1024 xc:'#121212' \
  -font "/path/to/MaterialIcons-Regular.otf" \
  -pointsize 550 -fill '#42A5F5' -gravity center \
  -annotate +0+0 $(printf '\U0000E5E3') app_icon.png

# Apply to all platforms
dart run flutter_launcher_icons
```
