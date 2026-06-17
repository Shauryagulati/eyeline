import Testing
@testable import EyelineKit

@Suite("TimedScrollDriver")
struct TimedScrollDriverTests {

    @Test("starts at rest at offset zero")
    func startsAtRest() {
        let driver = TimedScrollDriver(pointsPerSecond: 100)
        #expect(driver.offset == 0)
        #expect(driver.isPlaying == false)
    }

    @Test("accumulates offset at the configured speed while playing")
    func accumulatesWhilePlaying() {
        let driver = TimedScrollDriver(pointsPerSecond: 100)
        driver.play()
        driver.advance(to: 0)     // first tick after play: baseline only
        driver.advance(to: 1)     // +1s at 100 pts/s
        #expect(driver.offset == 100)
        driver.advance(to: 2.5)   // +1.5s
        #expect(driver.offset == 250)
    }

    @Test("freezes offset while paused")
    func freezesWhilePaused() {
        let driver = TimedScrollDriver(pointsPerSecond: 100)
        driver.play()
        driver.advance(to: 0)
        driver.advance(to: 1)     // offset 100
        driver.pause()
        driver.advance(to: 5)     // ignored while paused
        #expect(driver.offset == 100)
    }

    @Test("resuming does not jump forward for paused time")
    func resumeDoesNotJump() {
        let driver = TimedScrollDriver(pointsPerSecond: 100)
        driver.play()
        driver.advance(to: 0)
        driver.advance(to: 1)     // offset 100
        driver.pause()
        driver.advance(to: 10)    // ignored
        driver.play()
        driver.advance(to: 10)    // re-baseline after resume
        driver.advance(to: 11)    // +1s
        #expect(driver.offset == 200)
    }

    @Test("reset returns to the top")
    func resetReturnsToTop() {
        let driver = TimedScrollDriver(pointsPerSecond: 100)
        driver.play()
        driver.advance(to: 0)
        driver.advance(to: 3)     // offset 300
        driver.reset()
        #expect(driver.offset == 0)
    }

    @Test("seek sets the offset and continues from there")
    func seekContinues() {
        let driver = TimedScrollDriver(pointsPerSecond: 100)
        driver.seek(to: 250)
        #expect(driver.offset == 250)
        driver.play()
        driver.advance(to: 0)   // baseline (seek cleared the clock)
        driver.advance(to: 1)   // +100
        #expect(driver.offset == 350)
    }

    @Test("speed change applies to subsequent ticks only")
    func speedChangeAppliesGoingForward() {
        let driver = TimedScrollDriver(pointsPerSecond: 100)
        driver.play()
        driver.advance(to: 0)
        driver.advance(to: 1)        // offset 100 at 100 pts/s
        driver.pointsPerSecond = 200
        driver.advance(to: 2)        // +1s at 200 pts/s
        #expect(driver.offset == 300)
    }
}
