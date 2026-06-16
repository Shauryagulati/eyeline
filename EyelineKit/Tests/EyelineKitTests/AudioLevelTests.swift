import Testing
import Foundation
@testable import EyelineKit

@Suite("AudioLevel")
struct AudioLevelTests {

    @Test("silence maps to zero")
    func silenceIsZero() {
        #expect(AudioLevel.normalized(rms: 0) == 0)
    }

    @Test("at or below the floor maps to zero")
    func floorIsZero() {
        let rmsAtFloor = pow(10.0, -50.0 / 20.0)   // -50 dBFS
        #expect(AudioLevel.normalized(rms: rmsAtFloor, floorDB: -50, ceilDB: -10) == 0)
    }

    @Test("at or above the ceiling maps to one")
    func ceilingIsOne() {
        let rmsAtCeil = pow(10.0, -10.0 / 20.0)    // -10 dBFS
        #expect(AudioLevel.normalized(rms: rmsAtCeil, floorDB: -50, ceilDB: -10) == 1)
        #expect(AudioLevel.normalized(rms: 1.0, floorDB: -50, ceilDB: -10) == 1)  // 0 dBFS, clamped
    }

    @Test("the window midpoint maps to one half")
    func midpointIsHalf() {
        let rmsMid = pow(10.0, -30.0 / 20.0)       // -30 dBFS, midpoint of [-50, -10]
        let level = AudioLevel.normalized(rms: rmsMid, floorDB: -50, ceilDB: -10)
        #expect(abs(level - 0.5) < 0.0001)
    }
}
