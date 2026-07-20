# Sports Arena - Overview

Sports Arena is a generic live sports streaming client built with Flutter. It connects to any compatible streaming API and lets users watch live sports on Android (phone + TV) and Web.

## What It Does

- Fetches live streams from a user-provided streaming server
- Displays streams organized by sport categories
- Plays streams via an embedded WebView player
- Works on Android phones, Android TV / Fire Stick, and web browsers
- Blocks ad popups and new tab opens from the embed player

## How It Works

1. **First launch**: User enters their streaming server domain (e.g., `myserver.com`)
2. **App validates** the domain by hitting `/api/v1/categories`
3. **Domain is saved** locally — no need to re-enter on next launch
4. **Home screen** shows all live streams with category filtering and sorting
5. **Tap a stream** → opens the embedded player via WebView (Android) or iframe (Web)

## No Hardcoded URLs

The app contains zero references to any specific streaming provider. The user provides their own server domain during onboarding. This can be changed anytime from Settings.

## API Contract

The app expects the configured server to expose:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/categories` | GET | List of sport category names |
| `/api/v1/streams` | GET | All live streams (optional `?category=` filter) |
| `/api/v1/streams/{stream_key}` | GET | Single stream details (404 if not live) |
| `/embed/{category}/{stream_key}` | — | Embeddable stream player page |

### Stream object shape:
```json
{
  "id": "match-id",
  "name": "Team A vs Team B",
  "category": "soccer",
  "league": "Premier League",
  "stream_key": "team-a-vs-team-b",
  "match_timestamp": 1784487600,
  "viewers": 918,
  "thumbnail_url": "https://...",
  "embed_url": "https://server.com/embed/soccer/team-a-vs-team-b",
  "team1": { "name": "Team A", "logo": "https://..." },
  "team2": { "name": "Team B", "logo": "https://..." }
}
```
