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
            // Remember the window's position across launches; center only on first run. The window
            // is content-sized (non-resizable), so this effectively persists where the user put it.
            if !win.setFrameUsingName("EyelineSettings") { win.center() }
            win.setFrameAutosaveName("EyelineSettings")
            window = win
        }
        NSApp.setActivationPolicy(.regular)
        // Unlike Scripts, leave the notch panel floating on top while Settings is open: width, font,
        // mode and appearance changes preview live on the card, so the user needs to keep seeing it.
        // The Settings window centers below the notch, so it isn't covered in practice.
        // Forcefully bring the window forward + key (see AppActivation.bringToFront): the cooperative
        // NSApp.activate() leaves an agent app's window behind the currently-active app.
        AppActivation.bringToFront(window)
    }

    func windowWillClose(_ notification: Notification) {
        // Revert to menu-bar-only — but only if the Scripts window isn't still open (see
        // AppActivation): two policy-flipping windows must not strand each other. Settings never
        // changes the panel's level, so there's nothing to restore here (Scripts handles its own).
        if !AppActivation.otherTitledWindowVisible(besides: notification.object as? NSWindow) {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
