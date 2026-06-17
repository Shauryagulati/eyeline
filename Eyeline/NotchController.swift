import AppKit
import QuartzCore   // CACurrentMediaTime
import EyelineKit

// NSObject subclass so the scroll-loop Timer can use a target/selector callback — that avoids
// Swift 6 Sendable-capture errors from a closure-based timer.
@MainActor
final class NotchController: NSObject {
    /// Default scroll speed (points/second) for both timed and voice-gated scrolling.
    /// Lowered from 60 → reading pace; a live speed control lands in the customization pass.
    private static let defaultSpeed: Double = 30

    private let viewModel: TeleprompterViewModel
    private let panel: NotchPanel
    private var driver: ScrollDriver = TimedScrollDriver(pointsPerSecond: NotchController.defaultSpeed)
    private var amplitudeDriver: AmplitudeScrollDriver?
    private var voiceGated = false
    private let meter = MicLevelMeter()
    private let panelSize = PanelMetrics.size
    private var timer: Timer?

    override init() {
        viewModel = TeleprompterViewModel()
        panel = NotchPanel(rootView: TeleprompterView(model: viewModel))
        super.init()
        // The panel itself is the play/pause control — tapping it toggles playback.
        viewModel.onTogglePlay = { [weak self] in self?.togglePlay() }
    }

    func show() {
        repositionForActiveScreen()
        panel.orderFrontRegardless()

        // Both observers are delivered on .main (main thread = main actor); assumeIsolated
        // lets the calls into main-actor state stay statically known and warning-free. [fix #1]
        let center = NotificationCenter.default
        center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.repositionForActiveScreen() }
        }
        // Re-pin and re-assert front on wake (lid open / display reconfigure).
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.repositionForActiveScreen()
                self?.panel.orderFrontRegardless()
            }
        }
    }

    /// Switch between timed and voice-gated scrolling. Stops playback and returns to the top.
    func setVoiceGated(_ on: Bool) {
        pausePlayback()
        voiceGated = on
        if on {
            let d = AmplitudeScrollDriver(pointsPerSecond: NotchController.defaultSpeed)
            amplitudeDriver = d
            driver = d
        } else {
            amplitudeDriver = nil
            driver = TimedScrollDriver(pointsPerSecond: NotchController.defaultSpeed)
        }
        viewModel.offset = 0
    }

    func togglePlay() {
        if driver.isPlaying {
            pausePlayback()
            return
        }
        // Reached the end last time → start over from the top.
        if isAtEnd {
            driver.reset()
            viewModel.offset = 0
        }
        if voiceGated {
            MicPermission.ensureAccess { granted in
                Task { @MainActor in
                    guard granted else { self.presentMicDeniedAlert(); return }
                    self.startVoiceGatedPlayback()
                }
            }
        } else {
            driver.play()
            viewModel.isPlaying = true
            startTimer()
        }
    }

    /// Single pause path — stops the driver, the scroll loop, the mic, and clears the play state.
    private func pausePlayback() {
        driver.pause()
        stopTimer()
        meter.stop()
        viewModel.isPlaying = false
    }

    private func startVoiceGatedPlayback() {
        meter.onLevel = { [weak self] level in
            self?.amplitudeDriver?.ingest(level: level)
        }
        do {
            try meter.start()
            driver.play()
            viewModel.isPlaying = true
            startTimer()
        } catch {
            presentMicDeniedAlert(
                message: "Couldn't start the microphone: \(error.localizedDescription)")
        }
    }

    private func presentMicDeniedAlert(
        message: String = "Eyeline needs microphone access to scroll with your voice. "
            + "Enable it in System Settings ▸ Privacy & Security ▸ Microphone."
    ) {
        let alert = NSAlert()
        alert.messageText = "Microphone access needed"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func restart() {
        driver.reset()
        viewModel.offset = 0
    }

    /// Push new script text into the teleprompter (called by the app when selection/body changes).
    /// Switching scripts always returns the prompter to the top.
    func setText(_ text: String) {
        viewModel.text = text
        driver.reset()
        viewModel.offset = 0
    }

    // MARK: Scroll loop

    private func startTimer() {
        guard timer == nil else { return }
        // Target/selector form: Obj-C dispatches `tick` on the main run loop, so there is
        // no Sendable closure to trip Swift 6 concurrency checks.
        let t = Timer(timeInterval: 1.0 / 60.0,
                      target: self, selector: #selector(tick),
                      userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    @objc private func tick() {
        driver.advance(to: CACurrentMediaTime())
        viewModel.offset = driver.offset
        if isAtEnd { pausePlayback() }   // auto-stop once the end of the script is in view
    }

    /// True once the script has scrolled far enough that the remainder fits the visible area.
    /// Guards on a measured height so a not-yet-laid-out script never reads as "ended".
    private var isAtEnd: Bool {
        let visible = Double(panelSize.height - PanelMetrics.textInset * 2)
        let limit = ScrollBounds.maxOffset(
            contentHeight: Double(viewModel.contentHeight), visibleHeight: visible)
        return viewModel.contentHeight > 0 && viewModel.offset >= limit
    }

    // MARK: Positioning

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
