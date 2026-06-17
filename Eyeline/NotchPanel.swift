import AppKit
import SwiftUI

/// A borderless, non-activating panel pinned under the notch.
/// Borderless style avoids macOS repositioning the frame; non-activating keeps the user's current
/// app focused even when they tap the panel to play/pause.
final class NotchPanel: NSPanel {
    init(rootView: some View) {
        super.init(
            contentRect: NSRect(origin: .zero, size: PanelMetrics.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)

        isFloatingPanel = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false            // tappable for play/pause; non-activating keeps focus
        isMovableByWindowBackground = false

        let hosting = NSHostingView(rootView: rootView)
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting
    }

    override var canBecomeKey: Bool { false }
}
