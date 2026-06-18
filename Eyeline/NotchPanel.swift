import AppKit
import SwiftUI

/// A borderless, non-activating panel pinned under the notch.
/// Borderless style avoids macOS repositioning the frame; non-activating keeps the user's current
/// app focused even when they tap the panel to play/pause.
final class NotchPanel: NSPanel {
    init(rootView: some View) {
        super.init(
            contentRect: NSRect(
                origin: .zero,
                size: NSSize(width: PanelMetrics.defaultWidth, height: PanelMetrics.height)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)

        isFloatingPanel = true
        // Float above ordinary windows so the script stays readable while you work, but BELOW
        // pop-up menus and the menu bar (those live at .popUpMenu/.statusBar) so our own status-bar
        // menu can open in front of the card instead of behind it. A notch-docked panel never needs
        // to clear full-screen content — the notch area auto-hides in full screen anyway.
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true                      // opaque card casts a soft system shadow for depth
        ignoresMouseEvents = false            // tappable for play/pause; non-activating keeps focus
        isMovableByWindowBackground = false
        // A floating NSPanel hides itself when its host app deactivates by default. A menu-bar app
        // is effectively never the "active" app, so that default would sink the always-on-top card
        // behind other apps' windows the moment focus moved elsewhere. Pin it on top regardless.
        hidesOnDeactivate = false

        let hosting = NSHostingView(rootView: rootView)
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting
    }

    override var canBecomeKey: Bool { false }
}
