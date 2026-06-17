import Foundation
import Speech

/// The seam Voice mode talks to for recognized words. Keeping the recognizer behind a protocol
/// means a different engine (e.g. WhisperKit) can drop in later without touching the aligner,
/// driver, or wiring — the same discipline as the `ScrollDriver` seam in EyelineKit.
@MainActor
protocol SpeechSource: AnyObject {
    /// Called on the main actor with a rolling tail of the most recent recognized words.
    var onWords: (([String]) -> Void)? { get set }
    /// Begin recognizing. Throws if the audio engine or recognition session can't start.
    func start() throws
    /// Stop recognizing and release the audio engine.
    func stop()
}

/// Whether on-device speech recognition can run for Voice mode right now.
enum SpeechAvailability: Equatable {
    case available             // authorized AND on-device recognition supported
    case denied                // user declined, or restricted by policy
    case unsupportedOnDevice   // locale/device can't recognize on-device (we never go to network)
    case unavailable           // recognizer missing or temporarily unavailable
}

/// Thin wrapper over Speech-framework authorization plus the on-device support check. Mirrors
/// `MicPermission`. Voice mode requires *both* mic access (via `MicPermission`) and this.
enum SpeechPermission {

    /// Request speech-recognition authorization (prompting once if undetermined) and confirm the
    /// recognizer can run **on-device**. Completion may arrive off the main thread — callers hop
    /// to the main actor before touching UI. We never silently fall back to network recognition.
    static func ensureOnDeviceAccess(_ completion: @escaping @Sendable (SpeechAvailability) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            switch status {
            case .authorized:
                guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
                    completion(.unavailable)
                    return
                }
                completion(recognizer.supportsOnDeviceRecognition ? .available : .unsupportedOnDevice)
            case .denied, .restricted:
                completion(.denied)
            case .notDetermined:
                completion(.unavailable)
            @unknown default:
                completion(.unavailable)
            }
        }
    }
}
