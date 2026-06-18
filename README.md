# Eyeline

A free, open-source teleprompter for macOS that docks under the MacBook notch — so
you can read your script while looking straight at the camera and holding eye contact.

Eyeline is **100% local**: no network, no telemetry, no accounts. Everything — including
speech recognition — runs on your Mac and nothing is ever recorded or sent anywhere.

## Features

- **Docks under the notch.** The teleprompter card sits flush beneath the notch, right
  below the built-in camera, so your reading gaze lands on the lens.
- **Three scroll modes:**
  - **Timed** — scrolls at a steady, adjustable speed.
  - **Voice-gated** — scrolls only while you're speaking (driven by mic loudness).
  - **Read-along** — follows your actual words with on-device speech recognition and keeps
    your spoken place in view.
- **Tunable** — adjustable scroll speed, font size, and card width.
- **Global hotkeys** — play/pause, restart, and show/hide from anywhere.
- **Menu-bar app** — lives in the menu bar (no Dock clutter); optional launch at login.
- **On-device speech** — recognition is forced on-device, so audio never leaves your Mac.

## Install

1. Download the `.zip` from the
   [latest release](https://github.com/Shauryagulati/eyeline/releases/latest).
2. Unzip it and drag **Eyeline.app** into your `/Applications` folder.
3. Eyeline isn't notarized by Apple yet (it's a free project — no paid Developer account), so
   macOS Gatekeeper warns you the first time you open it. To get past it **once**:
   - **System Settings → Privacy & Security**, scroll to the bottom, and click **Open Anyway**; or
   - Control-click (right-click) `Eyeline.app` → **Open** → **Open**.
4. If macOS instead says the app **"is damaged and can't be opened,"** that's just the quarantine
   flag on an unsigned download — clear it with:
   ```bash
   xattr -dr com.apple.quarantine /Applications/Eyeline.app
   ```

Eyeline lives in your menu bar (no Dock icon) and runs entirely on-device — it never connects to
the network.

## Requirements (to build from source)

- macOS 14 or later
- Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (to generate the app project)

## Build from source

The repo has two parts: `EyelineKit/` is the pure-logic "brain" (a Swift Package, unit-tested
and headless), and `Eyeline/` is the thin AppKit + SwiftUI app shell.

```bash
# Run the brain's unit tests
swift test --package-path EyelineKit

# Generate the Xcode project from project.yml (needed after adding/removing source files)
xcodegen generate

# Build the app
xcodebuild -project Eyeline.xcodeproj -scheme Eyeline -destination 'platform=macOS' build
```

Or open `Eyeline.xcodeproj` in Xcode and press **Run**. The app is ad-hoc signed for local
use — no Apple Developer account required to build and run it yourself.

## Architecture

`EyelineKit` knows nothing about windows — it only computes numbers (scroll position,
notch geometry, voice/script alignment), so it tests headlessly. The app target bridges that
brain to AppKit (the notch panel, menu bar, and settings UI). Scroll behavior sits behind a
`ScrollDriver` protocol, so the timed, voice-gated, and read-along modes are interchangeable
implementations of the same seam.

## License

[MIT](LICENSE) — free to use, modify, and distribute.
