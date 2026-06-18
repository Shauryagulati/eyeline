import AppKit
import SwiftUI

/// Hosts `AboutView` in a small titled window. Like the Scripts/Settings windows, it flips the
/// LSUIElement app to `.regular` while open so the window shows front-most (with a Dock presence),
/// and reverts to `.accessory` on close — guarded by `AppActivation` so closing it never strands
/// another config window that's still open. The About window centers mid-screen, clear of the
/// always-on-top notch panel, so it needs no overlay-elevation handling.
@MainActor
final class AboutWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: AboutView())
            let win = NSWindow(contentViewController: hosting)
            win.title = "About Eyeline"
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
        // Revert to menu-bar-only only if no other policy-flipping window is still open.
        if !AppActivation.otherTitledWindowVisible(besides: notification.object as? NSWindow) {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
