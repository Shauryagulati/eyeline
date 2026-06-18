import AppKit

// Eyeline is a pure AppKit, menu-bar-only (LSUIElement) app — it deliberately does NOT use the
// SwiftUI `App`/`Scene` lifecycle. The previous `@main struct EyelineApp: App` wrapper hosted only
// an empty `Settings { EmptyView() }` scene (Eyeline has its own Settings window), yet SwiftUI's
// lifecycle installed its OWN main menu and replaced the Edit menu that `AppDelegate` builds once
// the app first became `.regular`. That silently broke ⌘X/⌘C/⌘V/⌘A in the Scripts editor — the
// responder chain was fine all along (proven: `NSApp.sendAction(paste:)` pasted correctly); only
// the menu was wrong, because SwiftUI's replacement menu had no Edit menu at all.
//
// Owning `NSApplication` directly keeps `AppDelegate`'s native Edit menu as the one true main menu,
// with the standard responder-chain validation (⌘V greys out when the pasteboard is empty, etc.).
// All the SwiftUI *views* still work — they're hosted in AppKit windows/panels via NSHostingView,
// which doesn't require the SwiftUI app lifecycle.
// Top-level code in main.swift is a nonisolated context, but the process entry point always
// runs on the main thread — so assert main-actor isolation to reach @MainActor AppDelegate's
// init, the (main-actor) delegate setter, and NSApplication.run(). `delegate` stays retained
// for the app's lifetime because run() blocks here until termination (NSApp.delegate is weak).
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
