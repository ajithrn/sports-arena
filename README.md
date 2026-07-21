# Sports Arena

Live sports streaming app built with Flutter. Supports Android (phone + TV), macOS, Windows, and Web.

[![Build & Release](https://img.shields.io/github/actions/workflow/status/ajithrn/sports-arena/build-release.yml?label=Build)](https://github.com/ajithrn/sports-arena/actions/workflows/build-release.yml) [![Latest](https://img.shields.io/badge/LATEST-v1.3.2-blue)](https://github.com/ajithrn/sports-arena/releases/latest) [![Download](https://img.shields.io/badge/DOWNLOAD-APK-green)](https://github.com/ajithrn/sports-arena/releases/latest/download/sports-arena-latest.apk) [![Downloader](https://img.shields.io/badge/DOWNLOADER-9563542-orange)](http://aftv.news/9563542)

## Features

- Browse live sports streams by category (Football, Cricket, Racing, Tennis, Basketball, Hockey, Combat, Baseball, Rugby)
- Stream playback via embedded player with fullscreen mode
- Category filtering, sorting (viewers, match time, name, league)
- Dark/Light/System theme
- Android TV support with D-pad navigation and Leanback launcher
- Configurable streaming server
- Auto-refresh, pull-to-refresh
- Ad/popup blocking
- DNS bypass proxy — works on ISPs that block streaming sites (DNS poisoning + SNI inspection)
- DoH fallback rotation with IP-based fallbacks (works even when ISP blocks DoH hostnames)
- Proxy-level ad blocking and JS overlay removal
- Configurable DoH (DNS-over-HTTPS) servers

## Documentation

Detailed docs are in the [docs/](docs/) folder:

- [Overview](docs/overview.md)
- [Setup](docs/setup.md)
- [Development](docs/development.md)
- [Architecture](docs/architecture.md)
- [Features](docs/features.md)
- [Proxy / DNS Bypass](docs/proxy.md)
- [Deployment](docs/deployment.md)
- [Releasing](docs/releasing.md)
- [Linux Build](docs/linux-build.md)

## Download

- **Android APK:** [Download Latest](https://github.com/ajithrn/sports-arena/releases/latest/download/sports-arena-latest.apk)
- **macOS (.dmg):** [Download Latest](https://github.com/ajithrn/sports-arena/releases/latest)
- **Windows (.zip):** [Download Latest](https://github.com/ajithrn/sports-arena/releases/latest)
- **Fire Stick / Android TV:** Enter code `9563542` in the [Downloader](http://aftv.news/9563542) app
- **Linux:** Build from source — see [Linux Build Instructions](docs/linux-build.md)
- **ADB:** `adb install sports-arena-latest.apk`
- **All releases:** [github.com/ajithrn/sports-arena/releases](https://github.com/ajithrn/sports-arena/releases)

### macOS Installation Note

macOS may block the app with a **"Sports Arena Not Opened"** warning since it's not notarized with Apple. To fix:

1. Open Terminal and run:
   ```bash
   xattr -cr "/Applications/Sports Arena.app"
   ```
   (If you didn't move it to Applications, use the path where the app is located, e.g., `~/Downloads/Sports Arena.app`)

2. Alternatively: **System Settings → Privacy & Security** → scroll down and click **Open Anyway**

### Platform Requirements

| Platform | Requirement |
|----------|-------------|
| Android | Android 7.0+ |
| macOS | macOS 10.15+ |
| Windows | Windows 10 1809+ with [WebView2 Runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/) |
| Linux | GTK 3, WebKitGTK 4.1 — [build from source](docs/linux-build.md) |

## License

Private project.
