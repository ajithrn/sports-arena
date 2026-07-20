# Linux Build Instructions

Sports Arena doesn't ship pre-built Linux binaries yet, but you can build it from source on any Linux distro with Flutter installed.

## Prerequisites

### Flutter SDK

Install Flutter 3.12+ with Linux desktop support enabled:

```bash
# Install Flutter (https://docs.flutter.dev/get-started/install/linux)
# Then enable Linux desktop:
flutter config --enable-linux-desktop
flutter doctor
```

### System Dependencies

Flutter Linux desktop apps use GTK, and this app requires WebKitGTK for stream playback.

**Debian / Ubuntu:**
```bash
sudo apt update
sudo apt install -y clang cmake git ninja-build pkg-config \
  libgtk-3-dev liblzma-dev libstdc++-12-dev \
  libwebkit2gtk-4.1-dev
```

**Fedora:**
```bash
sudo dnf install -y clang cmake git ninja-build pkg-config \
  gtk3-devel xz-devel \
  webkit2gtk4.1-devel
```

**Arch Linux:**
```bash
sudo pacman -S --needed clang cmake git ninja pkg-config \
  gtk3 xz \
  webkit2gtk-4.1
```

## Building

```bash
git clone https://github.com/ajithrn/sports-arena.git
cd sports-arena

# Add Linux platform support (generates linux/ directory)
flutter create --platforms=linux .

flutter pub get
flutter build linux --release
```

The output bundle is at:
```
build/linux/x64/release/bundle/
```

## Running

```bash
./build/linux/x64/release/bundle/sports_arena
```

## Installing (Optional)

You can copy the bundle to a system location:

```bash
sudo mkdir -p /opt/sports-arena
sudo cp -r build/linux/x64/release/bundle/* /opt/sports-arena/
sudo ln -sf /opt/sports-arena/sports_arena /usr/local/bin/sports-arena
```

Then run with:
```bash
sports-arena
```

### Desktop Entry

To add it to your application menu, create a `.desktop` file:

```bash
cat > ~/.local/share/applications/sports-arena.desktop << EOF
[Desktop Entry]
Name=Sports Arena
Comment=Live Sports Streaming
Exec=/opt/sports-arena/sports_arena
Icon=/opt/sports-arena/data/flutter_assets/assets/icon/app_icon.png
Type=Application
Categories=AudioVideo;Video;
EOF
```

## Notes

- **WebView dependency:** The app uses webview for stream playback. Linux support requires `webview_flutter_linux` or a compatible plugin backed by WebKitGTK. If the build fails on webview, you may need to add a Linux webview implementation to `pubspec.yaml`.
- **Wayland:** GTK apps work on both X11 and Wayland. If you encounter rendering issues on Wayland, try launching with `GDK_BACKEND=x11 sports-arena`.
- **ARM64:** If you're on an ARM64 Linux machine, replace `x64` with `arm64` in the paths above.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `flutter doctor` shows Linux not enabled | Run `flutter config --enable-linux-desktop` |
| Missing `libwebkit2gtk-4.1` | Install WebKitGTK dev package for your distro (see above) |
| `ninja: error: loading 'build.ninja'` | Run `flutter clean` then rebuild |
| App crashes on stream playback | Ensure WebKitGTK is installed and a Linux webview plugin is configured |
