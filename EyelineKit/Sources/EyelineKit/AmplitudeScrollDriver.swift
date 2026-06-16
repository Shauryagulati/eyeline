import Foundation

/// Voice-gated driver: scrolls at a constant speed only while recent audio is loud enough to
/// count as speech, and holds otherwise. Hysteresis (separate on/off thresholds) plus a release
/// window keep natural pauses between words from stuttering the scroll.
///
/// Conforms to the same `ScrollDriver` seam as `TimedScrollDriver`. Timing arrives through
/// `advance(to:)` and audio level through `ingest(level:)`, so the gating decision tests
/// headlessly with no microphone.
public final class AmplitudeScrollDriver: ScrollDriver {
    public private(set) var offset: Double = 0
    public private(set) var isPlaying = false

    /// Scroll speed in points per second while voiced.
    public var pointsPerSecond: Double
    /// Normalized level (0…1) at which a closed gate opens (speech starts).
    public var onThreshold: Double
    /// Normalized level (0…1) at which an open gate closes. Keep below `onThreshold`.
    public var offThreshold: Double
    /// Seconds to keep scrolling after the gate closes, so word gaps don't stutter.
    public var releaseInterval: Double

    private var currentLevel: Double = 0
    private var gateOpen = false
    private var lastVoicedTime: TimeInterval?
    private var lastTick: TimeInterval?

    public init(
        pointsPerSecond: Double = 60,
        onThreshold: Double = 0.2,
        offThreshold: Double = 0.1,
        releaseInterval: Double = 0.4
    ) {
        self.pointsPerSecond = pointsPerSecond
        self.onThreshold = onThreshold
        self.offThreshold = offThreshold
        self.releaseInterval = releaseInterval
    }

    /// Feed the latest normalized audio level (0…1). Called by the mic meter, off the protocol.
    public func ingest(level: Double) {
        currentLevel = level
    }

    public func play() {
        isPlaying = true
        lastTick = nil          // next advance() re-baselines the clock
        gateOpen = false
        lastVoicedTime = nil
    }

    public func pause() {
        isPlaying = false
        lastTick = nil
        gateOpen = false
        lastVoicedTime = nil
    }

    public func advance(to now: TimeInterval) {
        guard isPlaying else { return }
        defer { lastTick = now }     // keep the clock current every playing frame, voiced or not

        // Hysteresis: open above onThreshold, close below offThreshold, latch in between.
        if gateOpen {
            if currentLevel < offThreshold { gateOpen = false }
        } else {
            if currentLevel >= onThreshold { gateOpen = true }
        }
        if gateOpen { lastVoicedTime = now }

        // Voiced while the gate is open or we're still inside the release window.
        let voiced: Bool
        if gateOpen {
            voiced = true
        } else if let lastVoicedTime {
            voiced = (now - lastVoicedTime) <= releaseInterval
        } else {
            voiced = false
        }

        guard let lastTick, voiced else { return }
        let dt = now - lastTick
        if dt > 0 {
            offset += dt * pointsPerSecond
        }
    }

    public func reset() {
        offset = 0
        lastTick = nil
        gateOpen = false
        lastVoicedTime = nil
        currentLevel = 0
    }
}
