# TODO

## Ad Blocklist Expansion

The current blocklist is in `lib/config/blocked_domains.dart`. Plan to expand:

- [ ] Monitor proxy logs on different streams/events to discover new ad domains
- [ ] Consider fetching a remote blocklist (hosted on GitHub) so updates don't require app rebuild
- [ ] Add wildcard/pattern matching (e.g., `*.adnetwork.com`) instead of exact domain matches
- [ ] Consider integrating with community ad lists (EasyList domains) — filter to only streaming-relevant ones
- [ ] Add a settings option to let users add/remove blocked domains manually

## Connection UX — Contextual Error Messages & Recovery

Smart, interactive error handling that guides users to fix connection issues instead of showing blank screens.

### When stream list fails to load

| Condition | Message | Action Buttons |
|-----------|---------|----------------|
| Proxy OFF, connection fails | "Can't reach server. Your ISP may be blocking it." | [Enable Proxy] [Open Settings] |
| Proxy ON, DoH fails (all servers) | "DNS resolution failing. Try a different DNS server." | [Change DNS Server] [Try VPN] |
| Proxy ON, DoH works, tunnel fails | "Connection blocked by your network." | [Switch DNS] [Use VPN] [Open Settings] |
| Server domain invalid/unreachable | "Server not responding." | [Test Connection] [Change Server] |

### When player fails (stream list works but video blank/stuck)

| Condition | Message | Action Buttons |
|-----------|---------|----------------|
| Player timeout (>10s no content) | "Video not loading?" | [Retry] [Switch DNS] [Open Settings] |
| macOS system proxy not set | "Player can't bypass blocking. Grant network access." | [Retry] [Help] |
| ERR_PROXY_CONNECTION_FAILED | "Some content blocked. Try switching DNS server." | [Change DNS] |

### Implementation Plan

1. **ConnectionStatusProvider** — monitors proxy state, DoH health, last error type
2. **ConnectionBanner widget** — shows contextual message + action buttons on home screen
3. **PlayerErrorOverlay widget** — shows recovery options when video fails to load
4. **Inline action buttons** — "Enable Proxy" / "Change DNS" buttons execute the action directly from the error message (no need to navigate to Settings)
5. **Auto-detect blocking** — on first launch, test if server is reachable directly; if not, suggest enabling proxy

### UX Notes

- Proxy defaults to ON (current behavior, correct for users on blocking networks)
- Messages should be non-technical: "Your network is blocking this" not "DNS poisoning detected"
- Don't spam messages — show once per session or until user dismisses
- On macOS: if system proxy fails, explain that the app needs network permissions
- "Use VPN" suggestion as last resort fallback

## Auto Update Check on App Launch

Currently users must manually go to Settings → Check for updates. Add a background update check on app startup.

### Behavior

- Check GitHub releases API on app launch (after streams load, non-blocking)
- If new version available, show a non-intrusive banner/snackbar on home screen
- Banner shows: "Update available (v1.x.x)" with [Update] and [Dismiss] buttons
- Don't show again if user dismisses (persist dismissal for that version)
- Only check once per day (store last check timestamp)
- Don't block app usage — purely informational

### Implementation

1. Call `UpdateService.checkForUpdate()` in `HomeScreen.initState` (after initial load)
2. Store `last_update_check` and `dismissed_version` in SharedPreferences
3. Show `MaterialBanner` or `SnackBar` if update available and not dismissed
4. Tapping "Update" triggers the existing download/install flow


## Picture-in-Picture (PiP)

Allow users to watch streams in a small floating window while multitasking.

### Android (Real OS PiP)

- [ ] Add `android:supportsPictureInPicture="true"` to `AndroidManifest.xml` activity
- [ ] Add platform channel method to call `enterPictureInPictureMode()` from Flutter
- [ ] Add PiP button to player overlay (Android only)
- [ ] Handle `onUserLeaveHint` to auto-enter PiP when user presses home (optional)
- [ ] Hide overlay controls when in PiP mode (too small to interact with)
- [ ] Package: [`simple_pip_mode_flutter`](https://github.com/puntitowo/simple_pip_mode_flutter) or custom platform channel

### macOS / Windows (Compact Mode — fake PiP)

- [ ] Use `window_manager` to shrink window to ~320x180 and pin always-on-top
- [ ] Save original window size/position before entering compact mode (same pattern as fullscreen)
- [ ] Hide all chrome (overlay, title bar) in compact mode — just show the video
- [ ] Add a small restore button (or double-click to restore) to exit compact mode
- [ ] Add PiP/compact button to player overlay (desktop only)

### Notes

- macOS WKWebView does NOT support `allowsPictureInPictureMediaPlayback` (iOS only)
- Native macOS PiP requires `AVPlayerLayer` access — not possible with embedded iframes
- Desktop compact mode is the practical workaround using `window_manager` (already a dependency)
- Android real PiP works because the OS shrinks the entire Activity including the WebView
