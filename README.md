# Lid Duck

A self-contained native Swift/SwiftUI macOS menu-bar app. No packages, telemetry, networking, account, background service, login item, or changes to sleep/clamshell behavior.

## Build and run

Requires macOS 13+, Xcode Command Line Tools (Swift 5.9+) or full Xcode. An Apple account or paid developer membership is not required for a local build.

```sh
cd ~/Projects/lid-duck
zsh scripts/check-engine.sh
zsh scripts/build-app.sh
open "dist/Lid Duck.app"
```

The script creates an ad-hoc signed app in `dist`. It has no Dock icon: use the laptop icon in the menu bar. Optional: copy the app into Applications yourself. Quit an existing instance before opening another. Build is for the current Mac architecture; this is not a notarized distribution build.

## Menu-bar controls

The partially closed laptop icon dims when disabled. The popover header contains a compact native enable/disable switch, compact status and live angle. Healthy sensor messages are hidden; sensor/audio errors use a red indicator and switch accent with details immediately below. Manual override is summarized in the header. Enable/disable and sensor recovery refresh status immediately without requiring lid movement. The live angle keeps its larger rounded font; other values remain smaller.

Transition has a visual ruler every 250 ms, with longer labeled marks every 500 ms; adjustment remains in 1 ms steps. Duck volume uses a percentage badge and speaker endpoints. The bottom-left reset icon restores all defaults, including enabling the app; hover for its tooltip. Quit is at bottom right.

## Behavior and settings

Defaults: enabled, trigger strictly below 70°, restore strictly above 85°, each held for 250 ms; duck to at most 15% output volume over a 200 ms transition. Menu sliders expose both angles, duck volume (0–100%) and transition (0–2000 ms). Restore stays above trigger. Settings are local UserDefaults. Changing duck volume or duration applies to subsequent transitions; an in-progress fade uses the current duration.

The sensor and audio state are polled every 50 ms while awake, including while the popover is open. This gives roughly 250–300 ms threshold detection plus transition time; scheduling delays can increase latency. The hysteresis band preserves the current state. Ducking never raises audio that was already quieter; separate channel balance is retained. The mute flag is never changed.

A volume or master-mute change detected while ducked or fading cancels ownership and any saved restoration. Your chosen value remains untouched until the lid opens past the restore threshold for 250 ms; the next closing cycle captures a fresh baseline. Output-route changes likewise discard the old device's baseline and rearm after reopening. External changes smaller than the 0.002 scalar tolerance, or changes that return to exactly the expected value between polls, cannot reliably be detected. Concurrent writes can race within a polling interval.

Disable and normal Quit restore immediately when the app still owns the volume. Sensor loss restores with the configured fade. Before system sleep the app performs a best-effort immediate restore and pauses polling; after wake it probes again. It never prevents sleep. A force quit, crash, power loss, write failure, or inaccessible device can leave the current volume in place; there is deliberately no saved volume recovery across launches.

## Sensor approach and compatibility

Uses IOKit HID feature report 1 on Apple's vendor 0x05AC / product 0x8104 / sensor usage page 0x20 / usage 0x8A. A validated report contains the report ID followed by a little-endian whole-degree angle. It opens only this narrowly matched sensor, without exclusive access. Invalid reports are rejected; failed discovery retries every three seconds. Core Audio controls only the current default output device's writable master volume or all output channels.

Protocol references (independent implementation here, no source copied or vendored):

- [samhenrigold/LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor)
- [Yamete's dedicated HID feature-report implementation](https://github.com/Studnicky/yamete/blob/develop/Sources/SensorKit/LidAngleSource.swift)
- [macimu SPU/HID research](https://github.com/junwatu/macimu)

The feature-report approach avoids depending on privileged SPU streaming or undocumented IMU payload guesses. The sensor protocol is undocumented by Apple and can change across OS/hardware revisions.

Expected candidates include 14/16-inch Apple silicon MacBook Pro models with this HID sensor; other models work only if they expose the same report. Coverage is not guaranteed for a chip family. Older Intel models and some early Apple silicon Air/13-inch Pro models may not expose this interface. Desktop Macs have no lid sensor. Runtime availability is the source of truth, not a marketing model list. macOS 13 is the deployment target, not a claim of hardware-tested compatibility on every release.

Some HDMI, DisplayPort, USB, aggregate, Bluetooth, or virtual outputs lack writable software volume; the app shows an audio error and does not substitute keyboard scripting or alter another output. Unsupported/missing sensors show unavailable and cannot trigger ducking.

## Permissions

Designed to run as your ordinary user, without root, Accessibility, microphone, screen recording, or an Apple account. The narrowly matched sensor normally needs no Input Monitoring permission, but device access is OS-dependent. If the menu shows an access error, hardware/OS access remains unvalidated; do not run the app as root. This local app is not App Sandbox enabled or notarized. Standard macOS execution/security policy still applies.

## Development and validation

```sh
zsh scripts/check-engine.sh  # Standalone checks; Command Line Tools are sufficient
swift test                   # XCTest suite; full Xcode required
zsh scripts/build-app.sh     # Release build and ad-hoc signed app
```

See [validation notes](docs/VALIDATION.md) for coverage and the hardware checklist, and [changelog](CHANGELOG.md) for changes. GitHub Actions runs the checks and release build on macOS; physical lid and audio behavior require a MacBook.

## Project layout

```text
Sources/LidDuck/       Menu-bar UI, lid sensor, Core Audio, ducking engine
Tests/LidDuckTests/    XCTest behavior tests
scripts/              Local app build and standalone behavior checks
docs/                 Manual validation and compatibility notes
.github/workflows/    macOS continuous integration
Info.plist            Menu-bar app bundle configuration
Package.swift         Swift package definition
```

Build output (`.build/`, `dist/`), local editor settings and secrets are ignored by Git. The app has no third-party package dependencies.

## Uninstall

Quit using the menu first so any owned volume is restored. Delete the app and project folder. Optional: remove preferences with `defaults delete local.lid-duck.app`. There are no launch agents, services, accounts, or other installed components.
