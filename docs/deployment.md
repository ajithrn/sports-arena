# Deployment & Releases

## Automated Releases (GitHub Actions)

The repo has a GitHub Actions workflow that auto-builds and publishes a release APK when you push a version tag.

### Release a new version

```bash
# 1. Make changes and commit
git add -A && git commit -m "feat: your changes"

# 2. Bump version in pubspec.yaml and lib/config/app_config.dart

# 3. Tag it
git tag v1.2.0

# 4. Push
git push origin main --tags
```

GitHub Actions will:
1. Build the release APK
2. Create a GitHub Release
3. Attach `sports-arena-v1.2.0.apk`

Users download from: `https://github.com/ajithrn/sports-arena/releases/latest`

## Manual Build

```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

## Sideload on Android TV / Fire Stick

```bash
adb connect <tv-ip-address>
adb install app-release.apk
```

## Web Deployment

```bash
flutter build web
```

Deploy the `build/web/` folder to any static host (Netlify, Vercel, GitHub Pages, S3, etc.).

## Version Numbering

Format: `major.minor.patch+build`

- `pubspec.yaml` — `version: 1.1.1+3`
- `lib/config/app_config.dart` — `appVersion = '1.1.1'`

Both must be updated together before tagging.
