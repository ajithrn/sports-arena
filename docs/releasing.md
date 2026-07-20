# Releasing

## Automated Releases (GitHub Actions)

A GitHub Actions workflow at `.github/workflows/build-release.yml` automatically builds and publishes a release for all platforms on push to `main`.

### Steps to release:

1. **Bump version** in `pubspec.yaml` and `lib/config/app_config.dart`
2. **Update** `CHANGELOG.md` with the new version's changes
3. **Commit and push** to `main`

```bash
# Example: releasing v1.3.0
# 1. Edit pubspec.yaml → version: 1.3.0+6
# 2. Edit lib/config/app_config.dart → appVersion = '1.3.0'
# 3. Update CHANGELOG.md

git add -A
git commit -m "release: v1.3.0 - desktop platform support"
git push origin main
```

GitHub Actions will then:
- Check if the version tag already exists (skip if yes)
- Build Android APK on `ubuntu-latest`
- Build macOS DMG on `macos-latest`
- Build Windows ZIP on `windows-latest`
- Create a GitHub Release named "Sports Arena v1.3.0"
- Attach all platform artifacts

### Artifacts produced:

| Platform | Artifact |
|----------|----------|
| Android | `sports-arena-v1.3.0.apk`, `sports-arena-latest.apk` |
| macOS | `sports-arena-v1.3.0-macos.dmg` |
| Windows | `sports-arena-v1.3.0-windows.zip` |

### Manual Release (if Actions are down)

1. Build locally for your platform (see [deployment.md](deployment.md))
2. Go to https://github.com/ajithrn/sports-arena/releases/new
3. Create a new tag (e.g., `v1.3.0`)
4. Upload the built artifacts
5. Publish

## Version Numbering

Format: `MAJOR.MINOR.PATCH+BUILD`

- **MAJOR**: Breaking changes (new API contract, complete redesign)
- **MINOR**: New features (new platforms, new screens)
- **PATCH**: Bug fixes, small improvements
- **BUILD**: Incrementing integer for each release

## Checklist

- [ ] Version bumped in `pubspec.yaml`
- [ ] Version bumped in `lib/config/app_config.dart`
- [ ] `CHANGELOG.md` updated
- [ ] `flutter analyze` passes with no issues
- [ ] Local build succeeds for at least one platform
- [ ] Push to `main`

## Download URL

Users can always get the latest release at:
```
https://github.com/ajithrn/sports-arena/releases/latest
```
