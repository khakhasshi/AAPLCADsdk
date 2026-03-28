# Current Status

This document is the short handoff reference for humans or other AI agents working on the repository.

## Repository State

Current phase: `Phase 2 viewer interaction prototype`

Implemented and verified:

- Root CMake scaffold and repository layout
- Core placeholders: versioning, logging, `Result`, `ObjectId`, `Vector2d`
- Platform placeholders: platform info and input event abstraction
- Geometry placeholders: `Point2d`, `Line2d`, `Circle2d`, `Extents2d`
- Database placeholders: `Document`, `Layer`, `Transaction`, `Entity`, `LineEntity`
- Console example target: `aaplcad_minimal_viewer`
- macOS AppKit + MetalKit viewer prototype: `aaplcad_mac_viewer`
- Unit tests: `aaplcad_tests`
- Reusable 2D view-state abstraction for pan / zoom math
- Reusable 2D draw-list generation for visible line entities
- Screen-space line picking with entity id feedback
- Mouse click selection and highlight feedback in the macOS viewer
- Mouse drag panning and trackpad scrolling for canvas navigation
- Trackpad single-finger tap selection and three-finger pan support
- On-canvas debug coordinate overlay with `screen` and `world` readout
- Upright house sketch demo geometry for interaction testing

## Verified Commands

```bash
cmake -S . -B build
cmake --build build
ctest --test-dir build --output-on-failure
./build/aaplcad_minimal_viewer
./build/aaplcad_mac_viewer --smoke-test
```

## Current Viewer Capability

The macOS viewer currently provides:

- native AppKit window creation
- MetalKit view creation
- reusable 2D view state
- 2D document line rendering through a reusable draw-list builder
- mouse-based pan interaction
- scroll-wheel / trackpad scroll navigation
- line-entity click / tap selection with highlight feedback
- top-right debug overlay for current cursor `screen` and `world` coordinates
- house-sketch demo scene for navigation and picking regression checks

The viewer does not yet provide:

- robust two-finger pinch-zoom recovery across all touch paths
- multi-selection, box selection, or object snap
- command system, grips, or edit operations
- circle / arc / polyline rendering beyond line entities

## Phase Summary

This phase focused on turning the original viewer shell into a usable 2D interaction prototype.

Completed in this phase:

1. wired document line entities into a reusable draw-list path
2. rendered visible geometry through the current 2D view state
3. added screen-space line picking with entity-aware selection results
4. connected mouse and indirect-touch interaction to pan / select workflows
5. unified render-space and pick-space math for Retina-safe behavior
6. added lightweight on-screen debug feedback for cursor coordinate inspection

## Recommended Next Steps

Short-term priority:

- restore and verify two-finger pinch zoom without breaking custom touch gestures
- harden selection hit-testing on the house demo with regression coverage
- expand draw-list support beyond lines to more entity types
- add reusable interaction-state tests where logic can stay outside AppKit
- start a small command / selection-state abstraction instead of keeping all behavior in `main.mm`

After that:

- add trackpad-first navigation refinement
- add object snap and richer picking semantics
- prepare for edit commands and transient feedback

## Notes for Handoff

- Favor small, verifiable steps with working builds after each increment.
- Keep geometry/database logic independent from AppKit.
- Treat touchpad and desktop navigation as first-class requirements rather than optional polish.
- `apps/mac_viewer/main.mm` currently carries most prototype interaction logic and should be a refactoring target in the next phase.
- `cmake --build build` and `ctest --test-dir build --output-on-failure` remain the source of truth for validation.
