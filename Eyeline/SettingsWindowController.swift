import AppKit
import SwiftUI

/// Hosts `SettingsView` in a standard window. Like the Scripts window, it flips the app to a
/// `.regular` activation policy while open so controls (and Task 6's shortcut recorders) accept
/// keyboard input, reverting to `.accessory` on close.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let model: SettingsViewModel

    init(model: SettingsViewModel) {
        self.model = model
        super.init()
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(model: model))
            let win = NSWindow(contentViewController: hosting)
            win.title = "Eyeline Settings"
            win.styleMask = [.titled, .closable]
            win.isReleasedWhenClosed = false
            win.delegate = self
            win.center()
            window = win
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Revert to menu-bar-only — but only if the Scripts window isn't still open (see
        // AppActivation): two policy-flipping windows must not strand each other.
        if !AppActivation.otherTitledWindowVisible(besides: notification.object as? NSWindow) {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
