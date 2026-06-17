import Foundation
import Testing
@testable import EyelineKit

@Suite("ScriptAligner")
struct ScriptAlignerTests {
    // Tokens (normalized): hello world this is a teleprompter test for voice following alignment now
    //                        0     1    2   3  4      5         6    7    8       9         10     11
    static let script = "Hello world this is a teleprompter test for voice following alignment now"

    @Test("starts at the top with zero confidence")
    func startsAtTop() {
        let a = ScriptAligner(script: Self.script)
        #expect(a.lockedIndex == 0)
        #expect(a.confidence == 0)
        #expect(a.progressFraction == 0)
    }

    @Test("a clean read advances the locked index to the last spoken word")
    func cleanReadAdvances() {
        let a = ScriptAligner(script: Self.script)
        a.ingest(recentWords: ["hello", "world", "this"])
        #expect(a.lockedIndex == 2)            // "this"
        #expect(abs(a.confidence - 1.0) < 1e-9)
    }

    @Test("a continued read advances further forward")
    func continuedReadAdvances() {
        let a = ScriptAligner(script: Self.script)
        a.ingest(recentWords: ["hello", "world", "this"])
        a.ingest(recentWords: ["this", "is", "a", "teleprompter"])
        #expect(a.lockedIndex == 5)            // "teleprompter"
        #expect(abs(a.confidence - 1.0) < 1e-9)
    }

    @Test("ignores case and punctuation when matching")
    func normalizesInput() {
        let a = ScriptAligner(script: Self.script)
        a.ingest(recentWords: ["Hello,", "WORLD!", "This."])
        #expect(a.lockedIndex == 2)
        #expect(abs(a.confidence - 1.0) < 1e-9)
    }

    @Test("re-locks forward when the speaker skips ahead")
    func reLocksForward() {
        let a = ScriptAligner(script: Self.script)
        a.ingest(recentWords: ["voice", "following", "alignment"])
        #expect(a.lockedIndex == 10)           // "alignment"
        #expect(abs(a.confidence - 1.0) < 1e-9)
    }

    @Test("off-script input holds the index and decays confidence")
    func offScriptHolds() {
        let a = ScriptAligner(script: Self.script)
        a.ingest(recentWords: ["hello", "world", "this", "is", "a"])   // locks to 4, confidence 1
        #expect(a.lockedIndex == 4)
        a.ingest(recentWords: ["banana", "umbrella", "random", "gibberish"])
        #expect(a.lockedIndex == 4)            // held
        #expect(abs(a.confidence - 0.8) < 1e-9)  // 1.0 * decay(0.8)
    }

    @Test("a sub-threshold partial match holds rather than locking")
    func subThresholdHolds() {
        let a = ScriptAligner(script: Self.script)
        // last word "world" anchors at token 1, but only 1 of 2 compared match → 0.5 < 0.6.
        a.ingest(recentWords: ["xxx", "yyy", "world"])
        #expect(a.lockedIndex == 0)            // not locked
        #expect(a.confidence == 0)             // 0 * decay stays 0
    }

    @Test("an above-threshold partial match locks with that score as confidence")
    func partialAboveThresholdLocks() {
        let a = ScriptAligner(script: Self.script)
        // script[2,1,0] = this,world,hello vs this,XXX,hello → 2/3 ≈ 0.667 ≥ 0.6
        a.ingest(recentWords: ["hello", "XXX", "this"])
        #expect(a.lockedIndex == 2)
        #expect(abs(a.confidence - 2.0 / 3.0) < 1e-9)
    }

    @Test("progressFraction increases as the locked index advances")
    func progressFractionAdvances() {
        let a = ScriptAligner(script: Self.script)
        a.ingest(recentWords: ["hello", "world", "this"])
        let early = a.progressFraction
        a.ingest(recentWords: ["voice", "following", "alignment"])
        let late = a.progressFraction
        #expect(early > 0)
        #expect(late > early)
        #expect(late < 1)
    }

    @Test("reset returns to the top with zero confidence")
    func resetReturnsToTop() {
        let a = ScriptAligner(script: Self.script)
        a.ingest(recentWords: ["voice", "following", "alignment"])
        a.reset()
        #expect(a.lockedIndex == 0)
        #expect(a.confidence == 0)
        #expect(a.progressFraction == 0)
    }

    @Test("an empty script is inert and never divides by zero")
    func emptyScriptInert() {
        let a = ScriptAligner(script: "   ")
        a.ingest(recentWords: ["hello"])
        #expect(a.lockedIndex == 0)
        #expect(a.progressFraction == 0)
    }

    @Test("empty recent words holds without crashing")
    func emptyWordsHolds() {
        let a = ScriptAligner(script: Self.script)
        a.ingest(recentWords: ["hello", "world"])      // lock to 1
        let locked = a.lockedIndex
        a.ingest(recentWords: [])
        #expect(a.lockedIndex == locked)
    }

    @Test("does not lock to a match beyond the forward search window")
    func respectsForwardWindow() {
        let long = (0..<50).map { "w\($0)" }.joined(separator: " ")
        let a = ScriptAligner(script: long)        // default forward window = 30
        a.ingest(recentWords: ["w40", "w41"])      // token 41 is past index 0 + 30
        #expect(a.lockedIndex == 0)                // out of window → held
        a.ingest(recentWords: ["w5", "w6"])        // token 6 is within window
        #expect(a.lockedIndex == 6)
    }
}
