# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
