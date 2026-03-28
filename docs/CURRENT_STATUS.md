# Current Status

This document is the short handoff reference for humans or other AI agents working on the repository.

## Repository State

Current phase: `Bootstrap / early Phase 2-to-Phase 3 bridge`

Implemented and verified:

- Root CMake scaffold and repository layout
- Core placeholders: versioning, logging, `Result`, `ObjectId`, `Vector2d`
- Platform placeholders: platform info and input event abstraction
- Geometry placeholders: `Point2d`, `Line2d`, `Circle2d`, `Extents2d`
- Database placeholders: `Document`, `Layer`, `Transaction`, `Entity`, `LineEntity`
- Console example target: `aaplcad_minimal_viewer`
- macOS AppKit + MetalKit viewer prototype: `aaplcad_mac_viewer`
- Unit tests: `aaplcad_tests`

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
- clear-pass rendering shell
- reusable 2D view state
- basic pan and zoom interaction
- input event logging and reset behavior

The viewer does not yet provide:

- draw-list rendering of geometry
- selection / picking
- object snap or command interaction

## Active Development Direction

The next active implementation target is:

1. add a reusable 2D view state abstraction
2. wire scroll / magnify input to pan and zoom
3. render visible geometry through the current view state
4. keep the logic testable outside AppKit where possible

## Recommended Next Steps

Short-term priority:

- implement `ViewState2d` or equivalent camera abstraction
- add unit tests for pan / zoom math
- render a minimal 2D draw list using the current view state
- begin selection / picking prototype work

After that:

- add trackpad-first navigation refinement
- add navigation reset UI affordance
- begin selection / picking prototype work

## Notes for Handoff

- Favor small, verifiable steps with working builds after each increment.
- Keep geometry/database logic independent from AppKit.
- Treat touchpad and desktop navigation as first-class requirements rather than optional polish.
