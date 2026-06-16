import AppKit
import EyelineKit

// NSObject subclass so the scroll-loop Timer (added in Task 7) can use a target/selector
// callback — that avoids Swift 6 Sendable-capture errors from a closure-based timer.
@MainActor
final class NotchController: NSObject {
    private let viewModel: TeleprompterViewModel
    private let panel: NotchPanel
    private let panelSize = CGSize(width: 360, height: 140)

    override init() {
        viewModel = TeleprompterViewModel(script:
            "Paste your script here. Eyeline scrolls it right under your notch so your "
            + "eyes stay on the camera. This is the walking skeleton — constant-speed "
            + "scroll, play and pause from the menu bar. Keep reading and the text rolls "
            + "upward at a steady pace until it runs off the top.")
        panel = NotchPanel(rootView: TeleprompterView(model: viewModel))
        super.init()
    }

    func show() {
        repositionForActiveScreen()
        panel.orderFrontRegardless()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
            // Delivered on .main (main thread = main actor); assert that so the call into
            // main-actor state is statically known and warning-free (Swift-6-clean). [fix #1]
            MainActor.assumeIsolated { self?.repositionForActiveScreen() }
        }
    }

    /// Pin the panel under the notch of the notched display, falling back to main.
    private func repositionForActiveScreen() {
        let notched = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
        guard let screen = notched ?? NSScreen.main else { return }
        // On a notched display, safeAreaInsets.top spans the menu bar + notch, so the
        // panel lands just below the notch. On a NON-notched display safeAreaInsets.top
        // is 0 — using it would pin the panel over the menu bar — so fall back to the
        // menu-bar height (full frame top minus visible frame top). [review fix #2]
        let topInset = screen.safeAreaInsets.top > 0
            ? screen.safeAreaInsets.top
            : (screen.frame.maxY - screen.visibleFrame.maxY)
        let frame = NotchGeometry.panelFrame(
            screenFrame: screen.frame,
            topInset: topInset,
            size: panelSize)
        panel.setFrame(frame, display: true)
    }
}
