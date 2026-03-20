# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0] - 2026-03-20

### Added

- Floating settings bar appears when pressing the "down" button on fullscreen playback.
- Stream quality can be manually selected on the new settings bar.

## [1.3.1] - 2026-03-20

### Changed

- Video playback quality is no longer pinned to 2.5mpbs and will auto-select.

## [1.3.0] - 2026-03-20

### Added

- Anyonmized usage statistics. See "Telemetry Notice" section of README.md for details.

### Changed

- Version placeholders are added to various files and Makefile has been adjusted to automatically bump versions.

## [1.2.2] - 2026-03-19

### Fixed

- Exit confirmation is finally back and working. What a fucking pain that was.

## [1.2.1] - 2026-03-19

### Removed

- Exit confirmation has been temporarily moved due to a bug. Home button is now used to exit the app.

## [1.2.0] - 2026-03-19

### Added

- Fullscreen video display.
- Auto-hiding "Now Playing" bar.

### Fixed

- Small theme updates.

### Changed

- Camera list lives in a sliding panel.
- Logout button moved to "replay" (↻) button.

## [1.1.0] - 2026-03-19

### Added

- Access denied dialog when selecting a camera you don't have access to.
- Auto-restart stream if an offline camera comes back online.
- Exit confirmation dialog.
- Logout functionality with the `*` button.
- Pause support.

### Fixed

- Access level fetched from profile fixes camera access check.
- Camera list scroll position is preserved on list refresh.
- Added `--digest` flag to Makefile `curl` commands.

## [1.0.0] - 2026-03-18

### Added

- Email authentication flow.
- Dynamic camera listing.
- Camera uptime monitoring.
