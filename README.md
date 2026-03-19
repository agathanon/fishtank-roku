# Fishtank.live Roku PoC

Roku channel for watching Fishtank.live on your TV like a motherfucking boss.

## Features

- Full email/password login flow
- Camera selection
- Camera status refreshes

## Limitations

- No Google authentication flow
- No advanced site features

## Planned Features

- Various UI/UX improvements:
    - Fix camera access detection (Season Pass and Season Pass XL holders)
    - Fix auto-reset of camera list on refresh
    - Auto-hide camera list
    - True fullscreen
- Stox display
- Websocket support for live chat and site message overlays
- HTTP header nag
- Anonymized usage statistics

## Setup

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
