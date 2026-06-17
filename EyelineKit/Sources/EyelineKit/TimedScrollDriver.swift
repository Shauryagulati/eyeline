import Foundation

/// Phase 1 driver: scrolls at a constant speed while playing.
/// Deterministic — all timing arrives through `advance(to:)`, so it tests headlessly.
public final class TimedScrollDriver: ScrollDriver {
    public private(set) var offset: Double = 0
    public private(set) var isPlaying = false

    /// Scroll speed in points per second. Mutable so a speed slider can change it live.
    public var pointsPerSecond: Double

    private var lastTick: TimeInterval?

    public init(pointsPerSecond: Double = 60) {
        self.pointsPerSecond = pointsPerSecond
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
        if dt > 0 {
            offset += dt * pointsPerSecond
        }
    }

    public func seek(to offset: Double) {
        self.offset = offset
        lastTick = nil   // re-baseline so the next advance() doesn't add the gap as scroll
    }

    public func reset() {
        offset = 0
        lastTick = nil
    }
}
