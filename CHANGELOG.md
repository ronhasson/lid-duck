# Changelog

## Unreleased

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
