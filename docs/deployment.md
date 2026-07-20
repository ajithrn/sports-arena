# Deployment & Releases

## Automated Releases (GitHub Actions)

The repo has a GitHub Actions workflow that auto-builds and publishes releases for all platforms when you push to `main` with a new version.

### How it works

On every push to `main`, the workflow:
1. Reads the version from `pubspec.yaml`
2. Checks if a tag already exists for that version (skips if so)
3. Builds Android APK, macOS DMG, and Windows ZIP in parallel
4. Creates a GitHub Release with all artifacts attached

### Release a new version

```bash
# 1. Bump version in pubspec.yaml AND lib/config/app_config.dart
# 2. Commit and push to main

git add -A && git commit -m "release: v1.3.1"
git push origin main
```

The workflow auto-creates the tag and release. No manual tagging needed.

## Manual Builds

### Android

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### macOS

```bash
flutter build macos --release
```

Output: `build/macos/Build/Products/Release/Sports Arena.app`

To create a DMG:
```bash
mkdir -p dmg_contents
cp -R "build/macos/Build/Products/Release/Sports Arena.app" dmg_contents/
ln -s /Applications dmg_contents/Applications
hdiutil create -volname "Sports Arena" -srcfolder dmg_contents -ov -format UDZO Sports-Arena.dmg
rm -rf dmg_contents
```

### Windows

```bash
flutter build windows --release
```

Output: `build/windows/x64/runner/Release/`

Zip the entire Release folder for distribution.

### Web

```bash
flutter build web
```

Deploy the `build/web/` folder to any static host (Netlify, Vercel, GitHub Pages, S3, etc.).

## Platform Requirements

| Platform | Requirement |
|----------|-------------|
| Android | Android 7.0+ (SDK 24) |
| macOS | macOS 10.15+ with Xcode installed for building |
| Windows | Windows 10 1809+ with Visual Studio 2019+, WebView2 Runtime for running |
| Web | Any modern browser |

## Sideload on Android TV / Fire Stick

```bash
adb connect <tv-ip-address>
adb install app-release.apk
```

Or use the Downloader app with code: `9563542`

## Version Numbering

Format: `major.minor.patch+build`

- `pubspec.yaml` — `version: X.Y.Z+N`
- `lib/config/app_config.dart` — `appVersion = 'X.Y.Z'`

Both must be updated together before pushing.

## Download URLs

- Latest release: `https://github.com/ajithrn/sports-arena/releases/latest`
- Direct APK: `https://github.com/ajithrn/sports-arena/releases/latest/download/sports-arena-latest.apk`
