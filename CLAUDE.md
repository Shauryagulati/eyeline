# Eyeline — project guide for Claude

Free, open-source macOS teleprompter that docks under the MacBook notch so you read a
script while holding eye contact. Native Swift (SwiftUI + AppKit). MIT, built in public,
100% local — no network, no telemetry, no accounts.

## Layout

- `EyelineKit/` — SwiftPM package: the **pure-logic brain** (no AppKit/UI). Unit-tested,
  runs headlessly. Holds `ScrollDriver` (the protocol seam), `TimedScrollDriver`,
  `NotchGeometry`.
- `Eyeline/` — thin Xcode app target, menu-bar-only (`LSUIElement`): `EyelineApp`,
  `AppDelegate`, `NotchController`, `NotchPanel`, `TeleprompterView`.
- `project.yml` — XcodeGen spec (source of truth for the app project).
- `Eyeline.xcodeproj/` — **generated** by XcodeGen, committed for convenience.

Design rule: `EyelineKit` knows nothing about windows — it only computes numbers, so it
tests headlessly. `NotchController` is the one place that bridges the brain to AppKit.
One file = one responsibility.

## Build / run / test

```bash
# Brain — headless unit tests (TDD lives here)
swift test --package-path EyelineKit

# App — build
xcodebuild -project Eyeline.xcodeproj -scheme Eyeline -destination 'platform=macOS' build

# App — run: open Eyeline.xcodeproj and press ▶, or `open` the built .app from DerivedData
```

## Project generation (XcodeGen) — READ BEFORE TOUCHING THE PROJECT

The `.xcodeproj` is generated from `project.yml`. **Both are committed.**

- After **adding or removing** any `Eyeline/*.swift` file: run `xcodegen generate` before
  building, or the new file won't be in the target.
- **Never hand-edit `project.pbxproj`** or restructure the project in Xcode's GUI — edit
  `project.yml` and regenerate. GUI structural edits are lost on the next regen.
- Modifying the *contents* of existing files needs no regen.

## Conventions

- **TDD** for `EyelineKit` pure logic (Swift Testing: `@Test` / `@Suite` / `#expect`).
  The AppKit window / menu bar / SwiftUI shell is thin and verified by **manual dogfooding**.
- Min deployment target **macOS 14**. App target uses **Swift 5 language mode**
  (`SWIFT_VERSION=5.0`), matching `EyelineKit`'s `swiftLanguageModes: [.v5]`.

## Toolchain gotchas (Xcode 26.5 / Swift 6.3 — learned the hard way)

- AppKit `NotificationCenter` / `NSWorkspace` observer closures that capture `@MainActor self`
  need `MainActor.assumeIsolated { … }` to build warning-free (they're delivered on `.main`,
  so it's safe).
- `AppDelegate` is `@MainActor` so its `@objc` menu handlers can call the `@MainActor`
  `NotchController`.
- Swift Testing `#expect`: comparing a `CGFloat` against bare integer-literal arithmetic
  miscompares (the RHS is captured as `Int`) — wrap the expected value in `CGFloat(...)`.
- `swift test` creates `EyelineKit/.build/` (gitignored). Never `git add` a directory
  wholesale — it sweeps build artifacts in.

## Scope

Phased delivery. Phase 1: teleprompter + amplitude voice-gating. Phase 2: on-device
word-level voice-following (the `ScrollDriver` protocol is the seam it drops into).
Phase 3: maybe-later. Keep later-phase features out of earlier work.

Detailed design specs and implementation plans are kept as **private local working docs**
(gitignored) — not part of the repo.
