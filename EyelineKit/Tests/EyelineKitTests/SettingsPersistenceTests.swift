import Foundation
import Testing
@testable import EyelineKit

@Suite("SettingsPersistence")
struct SettingsPersistenceTests {
    @Test("in-memory backend returns its seed and counts saves")
    func inMemory() {
        let p = InMemorySettingsPersistence(settings: Settings(speed: 50, fontSize: 24, widthPreset: .wide))
        #expect(p.load().speed == 50)
        p.save(Settings(speed: 20, fontSize: 18, widthPreset: .ultraWide))
        #expect(p.saveCount == 1)
        #expect(p.load().widthPreset == .ultraWide)
    }

    @Test("UserDefaults backend returns defaults when nothing is stored")
    func userDefaultsEmpty() {
        let suite = UserDefaults(suiteName: "eyeline.settings.test.empty")!
        suite.removePersistentDomain(forName: "eyeline.settings.test.empty")
        let p = UserDefaultsSettingsPersistence(defaults: suite, key: "k")
        #expect(p.load() == Settings.defaults)
    }

    @Test("UserDefaults backend round-trips a saved value")
    func userDefaultsRoundTrip() {
        let suite = UserDefaults(suiteName: "eyeline.settings.test.rt")!
        suite.removePersistentDomain(forName: "eyeline.settings.test.rt")
        let p = UserDefaultsSettingsPersistence(defaults: suite, key: "k")
        let saved = Settings(speed: 65, fontSize: 30, widthPreset: .wide)
        p.save(saved)
        #expect(p.load() == saved)
    }
}
