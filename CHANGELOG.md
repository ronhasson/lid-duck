# Changelog

## Unreleased

## 0.2.4 — 2026-10-17

- First public packaged release for Apple Silicon Macs.
- Add an original laptop-and-volume Finder app icon; the menu-bar symbol is unchanged.
- Clear obsolete login errors after external state recovery.
- Add clean app bundle staging and a release ZIP with a SHA-256 checksum.
- Update the pinned checkout action to the current Node.js 24-compatible release.

## 0.2.3 — 2026-10-17

- Snap transition duration and its accessibility adjustments to 10 ms increments.
- Round previously saved transition values to the nearest 10 ms on launch.

## 0.2.2 — 2026-10-17

- Fix the profiled first-open stall in AppKit's native slider tick-cache layout.
- Keep native sliders continuous and round their bindings to whole-number settings instead of creating hundreds/thousands of native ticks.
- Preserve the transition ruler and one-unit accessibility adjustments.

## 0.2.1 — 2026-10-17

- Move all login-item queries and changes off the UI thread onto a serial worker.
- Cache installation eligibility instead of resolving the app path during view rendering.
- Coalesce overlapping login refreshes and show an accurate loading/disabled state.
- Avoid publishing unchanged angle/status values on every polling tick.

## 0.2.0 — 2026-10-17

- Preserve the original volume baseline when reclosing during restoration.
- Retain and validate restoration state across temporary audio-read failures.
- Retry a disabled app's pending restore after temporary audio unavailability.
- Add opt-in launch at login with system-state refresh, approval handling and errors.
- Require installation in Applications before registering launch at login.
- Keep launch-at-login registration separate from resetting ducking settings.
- Add regression coverage for interrupted fades, audio recovery and login-item state.

- Reduce the popover's bottom padding from 18 to 12 points.
- Organize validation documentation and add macOS build checks.

## 0.1.0 — 2026-10-17

- Native menu-bar app with local lid-angle sensing and system volume ducking.
- Configurable trigger/restore angles, duck volume and transition duration.
- Debounce, hysteresis and manual volume/output-route safeguards.
- Compact switch, live angle, error-only details and reset control.
- Fix status refresh when re-enabling or recovering the lid sensor.
- Standalone behavior checks, XCTest suite and local app bundle script.
