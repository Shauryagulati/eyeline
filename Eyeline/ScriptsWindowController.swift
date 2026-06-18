import AppKit
import SwiftUI

/// Hosts `ScriptsView` in a standard window. Because Eyeline is an LSUIElement (agent) app, a
/// window can't become key for keyboard input unless the app is a regular app — so we switch to
/// `.regular` while the editor is open and revert to `.accessory` when it closes (design spec §8.3).
@MainActor
final class ScriptsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let model: ScriptLibraryViewModel
    private let notch: NotchController

    init(model: ScriptLibraryViewModel, notch: NotchController) {
        self.model = model
        self.notch = notch
        super.init()
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: ScriptsView(model: model))
            let win = NSWindow(contentViewController: hosting)
            win.title = "Scripts"
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            win.setContentSize(NSSize(width: 760, height: 500))
            win.isReleasedWhenClosed = false
            win.delegate = self
            // Remember where the user put the window across launches; center only on first run
            // (no saved frame yet). setFrameAutosaveName then keeps it saved as they move/resize.
            if !win.setFrameUsingName("EyelineScripts") { win.center() }
            win.setFrameAutosaveName("EyelineScripts")
            window = win
        }
        // Become a regular app so the editor's TextField/TextEditor accept keyboard input.
        NSApp.setActivationPolicy(.regular)
        // Drop the always-on-top notch panel below this window so it can't cover the editor.
        notch.setOverlayElevated(false)
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Back to a menu-bar-only agent — but ONLY if no other managed window is still open.
        // Settings + Scripts each flip the activation policy; closing one while the other is
        // still on screen must not strand it under .accessory (no Dock icon, can't become key).
        if !AppActivation.otherTitledWindowVisible(besides: notification.object as? NSWindow) {
            NSApp.setActivationPolicy(.accessory)
            notch.setOverlayElevated(true)   // restore always-on-top once no config window remains
        }
    }
}
