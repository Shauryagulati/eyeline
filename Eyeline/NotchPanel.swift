import AppKit
import SwiftUI

/// A borderless, non-activating panel pinned under the notch.
/// Borderless style avoids macOS repositioning the frame; non-activating keeps
/// the user's current app focused when the panel shows.
final class NotchPanel: NSPanel {
    init(rootView: some View) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 140),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)

        isFloatingPanel = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true            // skeleton: click-through; controls come later
        isMovableByWindowBackground = false

        let hosting = NSHostingView(rootView: rootView)
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting
    }

    override var canBecomeKey: Bool { false }
}
