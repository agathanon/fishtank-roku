# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
