# Fishtank.live Roku PoC

_Roku channel for watching Fishtank.live on your TV like a motherfucking boss._

**For easy installation instructions, see [`INSTALL.md`](INSTALL.md).**

![Actual photo](.img/ui_photo_real_tv.jpg)

## Overview

### Features

- Full email/password login flow
- Sliding camera list
- Camera status refreshes
- Pause support
- Full screen player
- Anonymized usage statistics
- Adjustable stream quality

### Limitations

- No Google authentication flow
- No advanced site features

### Planned Features

- Stox display
- Websocket support for live chat and site message overlays
  - Roku doesn't support `wss://` so might start with just proxying announcements

## Telemetry Notice

This app collects **anonymous** usage data to help measure adoption and
improve the experience. Here's exactly what's collected:

**What's sent:**
- A randomly generated device ID (not tied to your Roku account or Fishtank account)
- Event type (app opened, camera switched, error occurred, etc.)
- App version, Roku model, and firmware version
- Camera ID when switching streams (e.g., `dirc-5`, not your personal viewing history)
- Timestamp

**What's NOT sent:**
- No Fishtank username, email, or user ID
- No IP address logging on the server
- No viewing duration or session tracking
- No personal information of any kind

**The code is right here** - the telemetry implementation is fully transparent:
- [`src/components/TelemetryTask.brs`](src/components/TelemetryTask.brs) - Roku-side sender code
- [`src/components/MainScene.brs`](src/components/MainScene.brs) - Contains calling of telemetry functions
- [`telemetry/src/server.py`](telemetry/src/server.py) - telemetry receiver API
- [`telemetry/src/config.py`](telemetry/src/config.py) - telemetry `gunicorn` configuration

The device ID is a random UUID generated on first launch and stored locally on
your Roku. It exists solely to distinguish "1 person opened the app 10 times"
from "10 people opened the app once." It cannot be linked to you.

Telemetry is fire-and-forget. If the server is unreachable, the app works
exactly the same. No data is queued or retried.

## Development

### Enabling Roku Developer Mode

On your Roku remote, go to **Settings → System → About**, then press:
**Home 3x → Up 2x → Right → Left → Right → Left → Right**

Set a developer password when prompted. Note your Roku's IP address.

### Prepare .env

Copy `env.example` to `.env` and populate with values.

### Build and Deploy

Run `make install`.

## Contributors

- [agathanonymous](https://x.com/agathanonymous)
