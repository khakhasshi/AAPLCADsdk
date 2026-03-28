# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project follows a pre-release style while the SDK is in early architecture and bootstrap stages.

## [Unreleased]

### Added
- Root CMake project scaffold for the Phase 1 bootstrap.
- Public header layout under `include/aaplcad/`.
- Initial `core` module placeholders for versioning, logging, result handling, object identifiers, and a basic 2D vector type.
- Initial `platform` module placeholder for platform detection and platform capability reporting.
- Initial `platform` input abstraction placeholder for pointer devices and modifier mapping.
- Initial `geometry` module placeholders for `Point2d`, `Line2d`, `Circle2d`, and `Extents2d`.
- Initial `graphics` view-state placeholder for 2D pan / zoom math.
- Initial `database` module placeholders for `Document`, `Layer`, `Transaction`, base `Entity`, and `LineEntity`.
- Minimal example target under `examples/minimal_viewer/`.
- macOS AppKit + Metal viewer prototype under `apps/mac_viewer/`.
- Basic unit test target under `tests/unit/`.
- Initial 2D draw-list builder for visible line entities based on `Document` + `ViewState2d`.
- Initial screen-space picking helper for line segments carried through the draw-list path.
- Extended repository directory skeleton for future `apps`, `plugins`, `resources`, integration tests, and performance tests.
- Root `.gitignore` for local build artifacts and editor noise.

### Changed
- Updated `README.md` to reflect the Phase 1 bootstrap status instead of design-only status.
- Added initial build instructions and repository structure overview.
- Updated the minimal example to create a demo document, layer, and line entity through the new Phase 2-facing APIs.
- Updated the build to include an Objective-C++ macOS viewer target linked with AppKit and MetalKit.
- Updated the macOS viewer prototype to use a reusable 2D view state for pan / zoom / reset interaction.
- Updated the macOS viewer prototype to render simple document line geometry through the new draw-list path.
- Updated the macOS viewer prototype to support click selection and highlight for line entities.

### Known Issues
- The macOS viewer now supports basic pan / zoom state, but still lacks geometry draw-list rendering, selection, and picking.
