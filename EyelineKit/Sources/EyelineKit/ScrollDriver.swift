import Foundation

/// The seam that lets Phase 2's speech-tracking driver drop in without rewriting the UI.
/// A driver owns one number: how far (in points) the script has scrolled.
public protocol ScrollDriver: AnyObject {
    /// Current scroll offset in points. Increases monotonically while playing.
    var offset: Double { get }
    /// Whether the driver is currently advancing.
    var isPlaying: Bool { get }
    /// Begin advancing on subsequent `advance(to:)` calls.
    func play()
    /// Stop advancing; `offset` holds its current value.
    func pause()
    /// Advance internal state to absolute time `now` (seconds, monotonic).
    /// Called once per render frame with a real timestamp; injected directly in tests.
    func advance(to now: TimeInterval)
    /// Jump the offset to an absolute value without animating, re-baselining the clock so the next
    /// `advance(to:)` doesn't lurch. Used when switching scroll modes so the freshly-installed
    /// driver adopts the current scroll position instead of snapping to the top.
    func seek(to offset: Double)
    /// Return to the top of the script.
    func reset()
}
