import AppKit
import SwiftUI

/// Hosts `SettingsView` in a standard window. Like the Scripts window, it flips the app to a
/// `.regular` activation policy while open so controls (and Task 6's shortcut recorders) accept
/// keyboard input, reverting to `.accessory` on close.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let model: SettingsViewModel
    private let notch: NotchController

    init(model: SettingsViewModel, notch: NotchController) {
        self.model = model
        self.notch = notch
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
            // Remember the window's position across launches; center only on first run. The window
            // is content-sized (non-resizable), so this effectively persists where the user put it.
            if !win.setFrameUsingName("EyelineSettings") { win.center() }
            win.setFrameAutosaveName("EyelineSettings")
            window = win
        }
        NSApp.setActivationPolicy(.regular)
        // Drop the always-on-top notch panel below this window so the user can see the settings
        // (the panel sits at the notch, exactly where this window centers).
        notch.setOverlayElevated(false)
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Revert to menu-bar-only — but only if the Scripts window isn't still open (see
        // AppActivation): two policy-flipping windows must not strand each other.
        if !AppActivation.otherTitledWindowVisible(besides: notification.object as? NSWindow) {
            NSApp.setActivationPolicy(.accessory)
            notch.setOverlayElevated(true)   // restore always-on-top once no config window remains
        }
    }
}
