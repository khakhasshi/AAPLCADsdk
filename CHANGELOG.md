# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project follows a pre-release style while the SDK is in early architecture and bootstrap stages.

## [Unreleased]

### Added
- Root CMake project scaffold for the Phase 1 bootstrap.
- Public header layout under `include/aaplcad/`.
- Initial `core` module placeholders for versioning, logging, result handling, object identifiers, and a basic 2D vector type.
- Initial `platform` module placeholder for platform detection and platform capability reporting.
- Minimal example target under `examples/minimal_viewer/`.
- Basic unit test target under `tests/unit/`.
- Extended repository directory skeleton for future `apps`, `plugins`, `resources`, integration tests, and performance tests.
- Root `.gitignore` for local build artifacts and editor noise.

### Changed
- Updated `README.md` to reflect the Phase 1 bootstrap status instead of design-only status.
- Added initial build instructions and repository structure overview.

### Known Issues
- Local build verification is currently blocked in the present environment because the `cmake` CLI is not installed or not available on `PATH`.
