# Releasing

## Automated Releases (GitHub Actions)

A GitHub Actions workflow at `.github/workflows/build-release.yml` automatically builds and publishes a release whenever a version tag is pushed.

### Steps to release:

1. **Bump version** in `pubspec.yaml` and `lib/config/app_config.dart`
2. **Commit** the changes
3. **Tag** with the version number
4. **Push** code and tag

```bash
# Example: releasing v1.2.0
# 1. Edit pubspec.yaml → version: 1.2.0+4
# 2. Edit lib/config/app_config.dart → appVersion = '1.2.0'

git add -A
git commit -m "release: v1.2.0"
git tag v1.2.0
git push origin main --tags
```

GitHub Actions will then:
- Build the release APK
- Create a GitHub Release named "Sports Arena v1.2.0"
- Attach the APK as `sports-arena-v1.2.0.apk`

### Manual Release (if Actions are down)

1. Build locally: `flutter build apk --release`
2. Go to https://github.com/ajithrn/sports-arena/releases/new
3. Select the tag
4. Upload the APK from `build/app/outputs/flutter-apk/app-release.apk`
5. Publish

## Version Numbering

Format: `MAJOR.MINOR.PATCH+BUILD`

- **MAJOR**: Breaking changes (new API contract, complete redesign)
- **MINOR**: New features (new screens, new settings)
- **PATCH**: Bug fixes, small improvements
- **BUILD**: Incrementing integer for each release

## Download URL

Users can always get the latest release at:
```
https://github.com/ajithrn/sports-arena/releases/latest
```
