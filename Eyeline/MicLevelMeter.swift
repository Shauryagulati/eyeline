import AVFoundation
import EyelineKit

/// Taps the default input device and reports a normalized 0…1 speech level on the main actor.
/// The RMS→level math lives in EyelineKit's `AudioLevel`; this class only owns the engine + tap.
@MainActor
final class MicLevelMeter {
    private let engine = AVAudioEngine()
    private var running = false

    /// dBFS window mapped to 0…1. Tuned on real hardware in Task 6.
    private let floorDB: Double = -50
    private let ceilDB: Double = -10

    /// Called on the main actor with each new normalized level (0…1).
    var onLevel: ((Double) -> Void)?

    func start() throws {
        guard !running else { return }
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)

        // Capture Sendable copies — the tap block runs on a realtime audio thread.
        let floor = floorDB
        let ceil = ceilDB
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            let rms = MicLevelMeter.rms(of: buffer)
            let level = AudioLevel.normalized(rms: rms, floorDB: floor, ceilDB: ceil)
            Task { @MainActor in self?.onLevel?(level) }
        }

        engine.prepare()
        try engine.start()
        running = true
    }

    func stop() {
        guard running else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        running = false
    }

    /// Linear RMS of the first channel of a buffer. `nonisolated` so the audio-thread tap can call it.
    nonisolated static func rms(of buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }
        let samples = channelData[0]
        var sumSquares = 0.0
        for i in 0..<frames {
            let s = Double(samples[i])
            sumSquares += s * s
        }
        return (sumSquares / Double(frames)).squareRoot()
    }
}
