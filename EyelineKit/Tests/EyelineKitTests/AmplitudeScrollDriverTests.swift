import Testing
@testable import EyelineKit

@Suite("AmplitudeScrollDriver")
struct AmplitudeScrollDriverTests {

    /// Helper: a driver with simple round-number tuning for deterministic assertions.
    private func makeDriver() -> AmplitudeScrollDriver {
        AmplitudeScrollDriver(
            pointsPerSecond: 100, onThreshold: 0.2, offThreshold: 0.1, releaseInterval: 0.3)
    }

    @Test("starts at rest at offset zero")
    func startsAtRest() {
        let driver = makeDriver()
        #expect(driver.offset == 0)
        #expect(driver.isPlaying == false)
    }

    @Test("holds while silent even though it is playing")
    func holdsWhileSilent() {
        let driver = makeDriver()
        driver.play()
        driver.ingest(level: 0.0)
        driver.advance(to: 0)
        driver.advance(to: 1)
        #expect(driver.offset == 0)
    }

    @Test("scrolls while the level is above the on-threshold")
    func scrollsWhileVoiced() {
        let driver = makeDriver()
        driver.play()
        driver.ingest(level: 0.5)   // above onThreshold 0.2
        driver.advance(to: 0)       // baseline + opens gate
        driver.advance(to: 1)       // +1s at 100 pts/s
        #expect(driver.offset == 100)
    }

    @Test("hysteresis keeps the gate open between the thresholds")
    func hysteresisKeepsOpen() {
        let driver = makeDriver()
        driver.play()
        driver.ingest(level: 0.5)   // opens
        driver.advance(to: 0)
        driver.advance(to: 1)       // offset 100
        driver.ingest(level: 0.15)  // below on (0.2) but above off (0.1) -> stays open
        driver.advance(to: 2)       // +1s still scrolling
        #expect(driver.offset == 200)
    }

    @Test("the release window keeps scrolling briefly after the gate closes")
    func releaseWindowBridgesGaps() {
        let driver = makeDriver()
        driver.play()
        driver.ingest(level: 0.5)
        driver.advance(to: 0)
        driver.advance(to: 1.0)     // offset 100, lastVoiced = 1.0
        driver.ingest(level: 0.0)   // silence -> gate closes
        driver.advance(to: 1.2)     // 0.2s after last voice, within release 0.3 -> still scrolls
        #expect(driver.offset == 120)
        driver.advance(to: 1.6)     // now 0.6s after last voice, past release -> holds
        #expect(driver.offset == 120)
    }

    @Test("resuming after pause does not jump for paused time")
    func resumeDoesNotJump() {
        let driver = makeDriver()
        driver.play()
        driver.ingest(level: 0.5)
        driver.advance(to: 0)
        driver.advance(to: 1)       // offset 100
        driver.pause()
        driver.advance(to: 10)      // ignored
        driver.play()
        driver.ingest(level: 0.5)
        driver.advance(to: 10)      // re-baseline
        driver.advance(to: 11)      // +1s voiced
        #expect(driver.offset == 200)
    }

    @Test("reset returns to the top and clears the gate")
    func resetReturnsToTop() {
        let driver = makeDriver()
        driver.play()
        driver.ingest(level: 0.5)
        driver.advance(to: 0)
        driver.advance(to: 2)       // offset 200
        driver.reset()
        #expect(driver.offset == 0)
    }
}
