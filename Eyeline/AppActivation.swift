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
}
