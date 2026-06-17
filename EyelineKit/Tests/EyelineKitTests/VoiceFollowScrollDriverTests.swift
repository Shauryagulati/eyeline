import Foundation
import Testing
@testable import EyelineKit

@Suite("VoiceFollowScrollDriver")
struct VoiceFollowScrollDriverTests {
    /// One frame of exponential smoothing toward a far target moves part-way, never past it.
    @Test("eases toward the target without overshooting in one frame")
    func easesTowardTarget() {
        let d = VoiceFollowScrollDriver(tau: 0.25, maxCatchUpPointsPerSecond: 100_000)
        d.setTarget(100)
        d.play()
        d.advance(to: 0)       // baseline tick
        d.advance(to: 0.1)     // dt = 0.1

        // 100 * (1 - exp(-0.1/0.25)) = 100 * (1 - exp(-0.4)) ≈ 32.968
        #expect(abs(d.offset - 32.96799539643607) < 1e-6)
        #expect(d.offset > 0)
        #expect(d.offset < 100)
    }

    @Test("converges to the target over many frames without exceeding it")
    func convergesToTarget() {
        let d = VoiceFollowScrollDriver(tau: 0.25, maxCatchUpPointsPerSecond: 100_000)
        d.setTarget(100)
        d.play()
        d.advance(to: 0)
        for i in 1...200 { d.advance(to: Double(i) * 0.1) }
        #expect(abs(d.offset - 100) < 0.5)
        #expect(d.offset <= 100)
    }

    /// With no fresh target, the offset rests where it converged — this *is* the "hold".
    @Test("holds in place when no new target arrives")
    func holdsWhenNoNewTarget() {
        let d = VoiceFollowScrollDriver(tau: 0.25, maxCatchUpPointsPerSecond: 100_000)
        d.setTarget(50)
        d.play()
        d.advance(to: 0)
        for i in 1...200 { d.advance(to: Double(i) * 0.1) }
        // Keep ticking with the same target — offset must not run away.
        for i in 201...400 { d.advance(to: Double(i) * 0.1) }
        #expect(abs(d.offset - 50) < 0.1)
    }

    /// A big re-lock jump is capped to maxCatchUp * dt so it glides instead of teleporting.
    @Test("clamps a large catch-up jump to maxCatchUp * dt")
    func clampsCatchUp() {
        let d = VoiceFollowScrollDriver(tau: 0.25, maxCatchUpPointsPerSecond: 500)
        d.setTarget(10_000)    // smoothing alone would want ~3297 pts this frame
        d.play()
        d.advance(to: 0)
        d.advance(to: 0.1)     // maxStep = 500 * 0.1 = 50
        #expect(abs(d.offset - 50) < 1e-9)
    }

    /// Re-lock backward (speaker repeated a line) is allowed but eased, never below 0.
    @Test("eases backward on a backward re-lock without undershooting")
    func easesBackward() {
        let d = VoiceFollowScrollDriver(tau: 0.25, maxCatchUpPointsPerSecond: 100_000)
        d.setTarget(100)
        d.play()
        d.advance(to: 0)
        for i in 1...200 { d.advance(to: Double(i) * 0.1) }   // converge near 100
        let high = d.offset
        d.setTarget(0)
        d.advance(to: 20.1)
        #expect(d.offset < high)
        #expect(d.offset >= 0)
    }

    @Test("pause freezes the offset")
    func pauseFreezes() {
        let d = VoiceFollowScrollDriver(tau: 0.25, maxCatchUpPointsPerSecond: 100_000)
        d.setTarget(100)
        d.play()
        d.advance(to: 0)
        d.advance(to: 0.1)
        let moved = d.offset
        d.pause()
        d.advance(to: 0.2)
        d.advance(to: 0.3)
        #expect(d.offset == moved)
    }

    /// Reset returns to the top AND clears the target, so it doesn't immediately ease back up.
    @Test("reset zeroes the offset and target")
    func resetZeroes() {
        let d = VoiceFollowScrollDriver(tau: 0.25, maxCatchUpPointsPerSecond: 100_000)
        d.setTarget(100)
        d.play()
        d.advance(to: 0)
        d.advance(to: 0.1)
        d.reset()
        #expect(d.offset == 0)
        d.advance(to: 0.2)     // would ease toward an old target if reset didn't clear it
        d.advance(to: 0.3)
        #expect(d.offset == 0)
    }

    @Test("the first tick after play only baselines the clock")
    func firstTickBaselines() {
        let d = VoiceFollowScrollDriver(tau: 0.25, maxCatchUpPointsPerSecond: 100_000)
        d.setTarget(100)
        d.play()
        d.advance(to: 5.0)     // no prior tick → no movement
        #expect(d.offset == 0)
    }
}
