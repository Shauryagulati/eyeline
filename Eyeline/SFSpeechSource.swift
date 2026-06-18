import AVFoundation
import Speech

/// On-device speech recognizer for Voice mode. Taps the default input, feeds an
/// `SFSpeechAudioBufferRecognitionRequest` with `requiresOnDeviceRecognition = true`, and emits a
/// rolling tail of the most recent recognized words on the main actor. The `ScriptAligner` only
/// ever sees that tail, so it stays agnostic to where one recognition session ends and the next
/// begins.
///
/// SFSpeech caps a single request's duration, so the session is restarted transparently when it
/// finalizes or errors: the committed tail carries across, the user sees no gap. Sibling of
/// `MicLevelMeter`; only one of the two runs at a time (Voice and Loudness modes are exclusive).
///
/// App-layer glue — verified by dogfooding, not unit tests (the alignment logic it feeds lives in
/// EyelineKit and is tested there).
@MainActor
final class SFSpeechSource: SpeechSource {
    var onWords: (([String]) -> Void)?
    /// Called on the main actor when recognition repeatedly fails to produce words and the source
    /// gives up (e.g. permission revoked mid-session). Lets the controller stop + surface it.
    var onUnavailable: (() -> Void)?

    private let recognizer: SFSpeechRecognizer
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var running = false

    /// Words finalized by previous sessions, kept so the rolling tail is continuous across
    /// restarts. Capped to `tailLength` — we only ever need the tail.
    private var committedWords: [String] = []
    /// How many trailing words to surface to the aligner each update.
    private let tailLength = 12
    /// Consecutive session restarts that produced no words. Reset whenever words come through; if
    /// it crosses the cap, recognition is broken (not just paused) and we stop instead of looping.
    private var restartsSinceWords = 0
    private let maxRestartsSinceWords = 8

    /// Fails if the current locale has no recognizer at all. On-device support is checked
    /// separately via `SpeechPermission.ensureOnDeviceAccess` before Voice mode commits.
    init?() {
        guard let r = SFSpeechRecognizer() else { return nil }
        recognizer = r
    }

    func start() throws {
        guard !running else { return }
        committedWords = []
        restartsSinceWords = 0
        try beginSession()
        running = true
    }

    func stop() {
        running = false
        endSession()
        committedWords = []
    }

    // MARK: - Session lifecycle

    private func beginSession() throws {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true   // 100% local — audio never leaves the device
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        self.request = request

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        // The tap runs on a realtime audio thread; capture only the Sendable request, not self.
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        try engine.start()

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // Delivered on an arbitrary queue — pull out Sendable primitives, then hop to main.
            let words = result.map { Self.split($0.bestTranscription.formattedString) }
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor in
                self?.handle(sessionWords: words, isFinal: isFinal, failed: failed)
            }
        }
    }

    private func endSession() {
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
    }

    /// Restart without dropping the rolling tail; ignored if Voice mode has stopped.
    private func restartSession() {
        guard running else { return }
        endSession()
        do {
            try beginSession()
        } catch {
            // The rebuild failed to get audio back — typically the input device went away mid-session
            // (AirPods disconnected, mic unplugged, device switched). The recognizer is now dead, not
            // merely paused, so surface it the same way the give-up path does instead of leaving Voice
            // mode "playing" against a recognizer that will never emit another word.
            running = false
            onUnavailable?()
        }
    }

    // MARK: - Result handling

    private func handle(sessionWords: [String]?, isFinal: Bool, failed: Bool) {
        guard running else { return }

        if let sessionWords, !sessionWords.isEmpty {
            let tail = Array((committedWords + sessionWords).suffix(tailLength))
            onWords?(tail)
            restartsSinceWords = 0          // recognition is alive; reset the failure counter
            if isFinal {
                // Fold this session's words into the carried tail before the next session starts.
                committedWords = tail
            }
        }

        guard isFinal || failed else { return }

        // A session that ended having produced nothing pushes the counter up; enough of those in a
        // row means recognition is broken (not merely a silent pause), so we give up rather than
        // spin restarting forever.
        restartsSinceWords += 1
        if restartsSinceWords > maxRestartsSinceWords {
            stop()
            onUnavailable?()
        } else {
            restartSession()
        }
    }

    private static func split(_ s: String) -> [String] {
        s.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }
}
