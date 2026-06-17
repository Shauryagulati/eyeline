import AppKit
import QuartzCore   // CACurrentMediaTime
import EyelineKit

// NSObject subclass so the scroll-loop Timer can use a target/selector callback — that avoids
// Swift 6 Sendable-capture errors from a closure-based timer.
@MainActor
final class NotchController: NSObject {
    private let viewModel: TeleprompterViewModel
    private let panel: NotchPanel
    private var driver: ScrollDriver = TimedScrollDriver(pointsPerSecond: Settings.defaults.speed)
    private var amplitudeDriver: AmplitudeScrollDriver?
    private var voiceDriver: VoiceFollowScrollDriver?
    private var mode: ScrollMode = .timed
    private let meter = MicLevelMeter()
    /// Voice mode only: on-device recognizer + the pure aligner that maps recognized words to a
    /// position in the script. Nil in other modes.
    private var speechSource: SFSpeechSource?
    private var aligner: ScriptAligner?
    /// Live panel width + scroll speed — seeded from the defaults, overwritten by Settings on launch
    /// and by the live apply methods below.
    private var currentWidth: CGFloat = PanelMetrics.defaultWidth
    private var currentSpeed: Double = Settings.defaults.speed
    private var timer: Timer?
    private var isVisible = true
    /// True only while a blocking alert (e.g. the mic-permission prompt) is on screen, so global
    /// hotkeys delivered into the modal run loop don't mutate scroll state behind the alert.
    private var isPresentingModal = false

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

    /// Hide the panel. Pauses first so it isn't scrolling out of sight.
    func hide() {
        pausePlayback()
        panel.orderOut(nil)
        isVisible = false
    }

    /// Re-pin to the active screen and show the panel.
    func reveal() {
        repositionForActiveScreen()
        panel.orderFrontRegardless()
        isVisible = true
    }

    /// Toggle panel visibility; returns the new visible state.
    func toggleVisible() -> Bool {
        if isVisible { hide() } else { reveal() }
        return isVisible
    }

    /// Lower the panel off the screen-saver level while a configuration window (Settings, Scripts)
    /// is open, so the always-on-top panel can't cover that window; restore it when the last such
    /// window closes. The panel stays on screen throughout, so live preview keeps updating.
    func setOverlayElevated(_ elevated: Bool) {
        panel.level = elevated ? .screenSaver : .normal
    }

    /// Apply a new scroll speed live — to the active driver and to any future driver.
    func setSpeed(_ pointsPerSecond: Double) {
        currentSpeed = pointsPerSecond
        (driver as? TimedScrollDriver)?.pointsPerSecond = pointsPerSecond
        amplitudeDriver?.pointsPerSecond = pointsPerSecond
    }

    /// Apply a new script font size. The view re-measures content height automatically.
    func setFontSize(_ points: Double) {
        viewModel.fontSize = CGFloat(points)
    }

    /// Apply a new panel width: resize + re-pin under the notch. Animated because this is a
    /// user-initiated change from Settings — a snap would feel jarring, an eased grow feels native.
    func setWidth(_ points: Double) {
        currentWidth = CGFloat(points)
        viewModel.width = CGFloat(points)
        repositionForActiveScreen(animated: true)
    }

    /// Switch the scroll mode from Settings. For Loudness/Voice this secures the required
    /// permissions *first* and commits the mode only on success — so the Settings picker never
    /// shows a mode "active" that can't actually run (M2). `completion(true)` means the mode took;
    /// `false` means it was rejected and the prior mode still stands. Switching never resets the
    /// scroll position (M3).
    func applyMode(_ newMode: ScrollMode, completion: @escaping (Bool) -> Void) {
        switch newMode {
        case .timed:
            commitMode(.timed)
            completion(true)

        case .loudness:
            MicPermission.ensureAccess { granted in
                Task { @MainActor in
                    if granted {
                        self.commitMode(.loudness)
                        completion(true)
                    } else {
                        self.presentMicDeniedAlert()
                        completion(false)
                    }
                }
            }

        case .voice:
            // Voice needs BOTH microphone access and on-device speech recognition.
            MicPermission.ensureAccess { micGranted in
                Task { @MainActor in
                    guard micGranted else {
                        self.presentMicDeniedAlert()
                        completion(false)
                        return
                    }
                    SpeechPermission.ensureOnDeviceAccess { availability in
                        Task { @MainActor in
                            guard availability == .available else {
                                self.presentSpeechUnavailableAlert(availability)
                                completion(false)
                                return
                            }
                            self.commitMode(.voice)
                            completion(true)
                        }
                    }
                }
            }
        }
    }

    /// Restore the persisted mode at launch *without* prompting — first play acquires permissions.
    /// A menu-bar app shouldn't throw a permission dialog before the user has done anything.
    func restoreMode(_ mode: ScrollMode) {
        commitMode(mode)
    }

    /// Tear down the old mode's resources and install the new mode's driver, preserving the current
    /// scroll position (M3 — only `restart()`/`setText()` return to the top).
    private func commitMode(_ newMode: ScrollMode) {
        pausePlayback()
        let position = viewModel.offset
        amplitudeDriver = nil
        voiceDriver = nil
        aligner = nil
        speechSource = nil

        switch newMode {
        case .timed:
            driver = TimedScrollDriver(pointsPerSecond: currentSpeed)
        case .loudness:
            let d = AmplitudeScrollDriver(pointsPerSecond: currentSpeed)
            amplitudeDriver = d
            driver = d
        case .voice:
            let d = VoiceFollowScrollDriver()
            voiceDriver = d
            driver = d
            aligner = ScriptAligner(script: viewModel.text)
            speechSource = SFSpeechSource()
        }

        driver.seek(to: position)   // keep the current scroll position across the switch (M3)
        mode = newMode
    }

    func togglePlay() {
        guard !isPresentingModal else { return }
        // A hotkey can arrive while the panel is hidden — reveal it so the user sees the result
        // of the command they just issued rather than nothing happening.
        if !isVisible { reveal() }
        if driver.isPlaying {
            pausePlayback()
            return
        }
        // Reached the end last time → start over from the top.
        if isAtEnd {
            driver.reset()
            viewModel.offset = 0
            aligner?.reset()
        }
        startPlayback()
    }

    /// Begin scrolling in the current mode. Permissions were secured when the mode was chosen
    /// (applyMode), so this just spins up the audio pipeline the mode needs and starts the loop.
    private func startPlayback() {
        switch mode {
        case .timed:
            beginScrollLoop()

        case .loudness:
            meter.onLevel = { [weak self] level in self?.amplitudeDriver?.ingest(level: level) }
            do {
                try meter.start()
            } catch {
                presentMicDeniedAlert(
                    message: "Couldn't start the microphone: \(error.localizedDescription)")
                return
            }
            beginScrollLoop()

        case .voice:
            guard let speechSource else {
                presentSpeechUnavailableAlert(.unavailable)
                return
            }
            speechSource.onWords = { [weak self] words in
                guard let self, let aligner = self.aligner else { return }
                aligner.ingest(recentWords: words)
                self.updateVoiceTarget()
            }
            // If the recognizer gives up (e.g. permission revoked since launch), stop cleanly.
            speechSource.onUnavailable = { [weak self] in
                guard let self else { return }
                self.pausePlayback()
                self.presentSpeechUnavailableAlert(.unavailable)
            }
            do {
                try speechSource.start()
            } catch {
                presentSpeechUnavailableAlert(.unavailable)
                return
            }
            beginScrollLoop()
        }
    }

    private func beginScrollLoop() {
        driver.play()
        viewModel.isPlaying = true
        startTimer()
    }

    /// Single pause path — stops the driver, the scroll loop, all audio inputs, and the play state.
    private func pausePlayback() {
        driver.pause()
        stopTimer()
        meter.stop()
        speechSource?.stop()
        viewModel.isPlaying = false
    }

    /// Geometry bridge (Voice mode): convert the aligner's progress (0…1 by character) into a
    /// target scroll offset that centers the spoken word, and hand it to the voice driver to glide
    /// toward. Inert until the content has been measured, so it never divides by zero.
    private func updateVoiceTarget() {
        guard let voiceDriver, let aligner else { return }
        let contentHeight = Double(viewModel.contentHeight)
        guard contentHeight > 0 else { return }
        let visible = Double(PanelMetrics.height - PanelMetrics.textInset * 2)
        let wordY = aligner.progressFraction * contentHeight
        let maxOffset = ScrollBounds.maxOffset(contentHeight: contentHeight, visibleHeight: visible)
        let target = min(max(wordY - visible / 2, 0), maxOffset)
        voiceDriver.setTarget(target)
    }

    private func presentMicDeniedAlert(
        message: String = "Eyeline needs microphone access to scroll with your voice. "
            + "Enable it in System Settings ▸ Privacy & Security ▸ Microphone."
    ) {
        isPresentingModal = true
        defer { isPresentingModal = false }
        let alert = NSAlert()
        alert.messageText = "Microphone access needed"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// Explain why Voice mode can't run. Distinct copy per cause so the user knows whether to grant
    /// permission, switch language, or just try again — and reassures that audio stays on-device.
    private func presentSpeechUnavailableAlert(_ availability: SpeechAvailability) {
        let title: String
        let message: String
        switch availability {
        case .denied:
            title = "Speech recognition access needed"
            message = "Eyeline needs Speech Recognition access to follow your voice. Enable it in "
                + "System Settings ▸ Privacy & Security ▸ Speech Recognition."
        case .unsupportedOnDevice:
            title = "On-device speech unavailable"
            message = "Your Mac can't run on-device speech recognition for the current language, "
                + "so Voice mode isn't available. Eyeline never sends audio off your device — "
                + "try Loudness mode instead."
        case .available, .unavailable:
            title = "Voice mode unavailable"
            message = "Eyeline couldn't start speech recognition right now. Try again, or use "
                + "Loudness mode."
        }
        isPresentingModal = true
        defer { isPresentingModal = false }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func restart() {
        guard !isPresentingModal else { return }
        if !isVisible { reveal() }
        driver.reset()
        viewModel.offset = 0
        aligner?.reset()
    }

    /// Push new script text into the teleprompter (called by the app when selection/body changes).
    /// Switching scripts always returns the prompter to the top.
    func setText(_ text: String) {
        viewModel.text = text
        driver.reset()
        viewModel.offset = 0
        // Re-tokenize for the new script so Voice mode aligns against the right words.
        if mode == .voice { aligner = ScriptAligner(script: text) }
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
        let visible = Double(PanelMetrics.height - PanelMetrics.textInset * 2)
        let limit = ScrollBounds.maxOffset(
            contentHeight: Double(viewModel.contentHeight), visibleHeight: visible)
        return viewModel.contentHeight > 0 && viewModel.offset >= limit
    }

    // MARK: Positioning

    /// Pin the panel under the notch of the notched display, falling back to main.
    /// `animated` is true only for user-initiated width changes; screen reconfigure / wake re-pin
    /// instantly so the panel never appears to drift after a display change.
    private func repositionForActiveScreen(animated: Bool = false) {
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
            size: CGSize(width: currentWidth, height: PanelMetrics.height))
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }
}
