# Validation

Run `zsh scripts/check-engine.sh` for standalone deterministic fake-audio checks of debounce reset, hysteresis, restore, manual override/rearm, route changes, fade interruption, sensor failure, disable, quiet audio, channel balance, and mute override. These tests do not exercise the physical sensor or real output device. An additional XCTest suite is available via `swift test` when full Xcode with XCTest is installed; the Command Line Tools on the implementation host lack XCTest.

User-confirmed checks: the app runs and the reset button works. The following checks remain required for broader validation:

1. Open the built app and confirm the icon/popover, controls, persistence and live angle agree with physical lid movement on your exact model/OS.
2. Play quiet audio, hold below 70° for >250 ms, confirm ducking; move within 70–85° and confirm no toggling; hold above 85° and confirm restoration. Brief crossings should do nothing.
3. Change volume and mute using keys/Control Center during ducking and both fades. Confirm no stale restore and that reopening rearms a new closing cycle.
4. Switch among speakers/headphones/Bluetooth/HDMI while ducked and during fades. Confirm no stale baseline is applied to the new route and unsupported routes show an error.
5. Disable and quit during ducking and each fade. Sleep/wake and unplug outputs. Check normal system sleep behavior remains intact and valid angle reads resume.
6. Check long-running CPU/energy usage and actual audio-driver rounding. Test macOS 13+ releases and additional hardware before claiming broader support.

## Local verification record

The implementation host uses Apple Silicon and the macOS 27 SDK / Swift 6.4 Command Line Tools. The release build and standalone checks are the local verification path; XCTest requires full Xcode. Physical hardware/volume and UI behavior remain manual validation items above, not certified compatibility claims.
