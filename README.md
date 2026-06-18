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

### Option A — Homebrew (easiest)

```bash
brew install --cask shauryagulati/tap/eyeline
```

That's it — the app opens normally. Eyeline isn't notarized by Apple yet (it's a free project
with no paid Developer account), so the cask clears the macOS quarantine flag for you on install.
Update or remove it later with `brew upgrade --cask eyeline` / `brew uninstall --cask eyeline`.

### Option B — Download the app

1. Download the `.zip` from the
   [latest release](https://github.com/Shauryagulati/eyeline/releases/latest).
2. Unzip it and drag **Eyeline.app** into your `/Applications` folder.
3. Because Eyeline isn't notarized, macOS blocks the first launch (you'll see a warning that it
   "could not be verified"). Clear the quarantine flag once and it opens normally afterward:
   ```bash
   xattr -dr com.apple.quarantine /Applications/Eyeline.app
   ```
   Prefer not to use Terminal? Try to open the app, click **Done** on the warning (**not** Move to
   Trash), then go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**.

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
