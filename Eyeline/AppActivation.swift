import AppKit

/// Coordinates the LSUIElement app's activation policy across the multiple titled windows that
/// each need `.regular` to accept keyboard input (Scripts, Settings). Without this, closing one
/// window while another is still open would revert the app to `.accessory` and strand the open
/// window (no Dock icon, can't become key).
enum AppActivation {
    /// True if any titled window other than `closing` is still on screen. The borderless,
    /// non-activating teleprompter panel isn't `.titled`, so it's correctly ignored.
    @MainActor
    static func otherTitledWindowVisible(besides closing: NSWindow?) -> Bool {
        NSApp.windows.contains {
            $0 !== closing && $0.isVisible && $0.styleMask.contains(.titled)
        }
    }

    /// Bring `window` forward as the key window for an LSUIElement app that has just switched to
    /// `.regular`. The no-argument `NSApp.activate()` is *cooperative* on macOS 14+ — it yields to
    /// whatever app is currently frontmost — so an agent app's on-demand window opens *behind* the
    /// active app and never becomes key. With no key window there is no first responder, so the
    /// Edit-menu shortcuts (⌘X/⌘C/⌘V/⌘A) silently no-op in the editor. The deprecated forceful
    /// variant is the only API that reliably pulls the window forward, which is exactly the UX the
    /// user asked for by choosing a menu item; `orderFrontRegardless` covers the activation handoff.
    @MainActor
    static func bringToFront(_ window: NSWindow?) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}
