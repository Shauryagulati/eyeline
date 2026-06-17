import Foundation

/// Phase 2 driver: glides the scroll offset toward a target offset supplied from outside (the
/// word-aligner's locked position, converted to points by the geometry bridge). Each frame it
/// eases a fraction of the remaining distance via exponential smoothing, capped so a big re-lock
/// jump slides rather than teleports. When no fresh target arrives, the offset converges to the
/// last target and rests in place — that resting *is* the "hold" while the speaker is off-script.
///
/// Conforms to the same `ScrollDriver` seam as the other drivers. Timing arrives through
/// `advance(to:)` and the goal through `setTarget(_:)`, so the easing tests headlessly with no
/// microphone or speech recognizer.
///
/// Note: unlike the timed/loudness drivers this one may ease *backward* when the speaker repeats
/// an earlier line and the aligner re-locks to a lower index. That backward motion is deliberate
/// (and eased + clamped just like forward), so the protocol's "monotonic" note doesn't hold here.
public final class VoiceFollowScrollDriver: ScrollDriver {
    public private(set) var offset: Double = 0
    public private(set) var isPlaying = false

    /// Smoothing time constant (seconds). Larger = lazier glide; ~0.25 s feels natural.
    public var tau: Double
    /// Hard cap on how fast the offset may move toward the target (points/second), so a large
    /// re-lock distance glides over several frames instead of jumping in one.
    public var maxCatchUpPointsPerSecond: Double

    private var target: Double = 0
    private var lastTick: TimeInterval?

    public init(tau: Double = 0.25, maxCatchUpPointsPerSecond: Double = 800) {
        self.tau = tau
        self.maxCatchUpPointsPerSecond = maxCatchUpPointsPerSecond
    }

    /// Supply a fresh goal offset (in points). The driver eases toward it on subsequent frames.
    public func setTarget(_ offset: Double) {
        target = offset
    }

    public func play() {
        isPlaying = true
        lastTick = nil   // the next advance() re-establishes the clock origin
    }

    public func pause() {
        isPlaying = false
        lastTick = nil
    }

    public func advance(to now: TimeInterval) {
        guard isPlaying else { return }
        defer { lastTick = now }
        guard let last = lastTick else { return }   // first tick after play: baseline only
        let dt = now - last
        guard dt > 0 else { return }

        // Exponential approach to the target: cover a fraction (1 - e^(-dt/tau)) of the gap.
        // tau <= 0 degenerates to an instant snap (factor 1).
        let factor = tau > 0 ? (1 - exp(-dt / tau)) : 1
        var step = (target - offset) * factor

        // Clamp the per-frame move so a far target glides in rather than teleporting.
        let maxStep = maxCatchUpPointsPerSecond * dt
        if step > maxStep { step = maxStep }
        else if step < -maxStep { step = -maxStep }

        offset += step
    }

    public func reset() {
        offset = 0
        target = 0          // clear the goal too, so we don't immediately ease back up
        lastTick = nil
    }
}
