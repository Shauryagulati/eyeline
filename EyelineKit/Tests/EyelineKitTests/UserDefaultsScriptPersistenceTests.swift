import Testing
import Foundation
@testable import EyelineKit

@Suite("UserDefaultsScriptPersistence")
struct UserDefaultsScriptPersistenceTests {

    /// A throwaway UserDefaults suite per test so cases don't bleed into each other.
    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "eyeline.test.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite)!, suite)
    }

    @Test("returns an empty state when nothing is stored")
    func emptyWhenAbsent() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let persistence = UserDefaultsScriptPersistence(defaults: defaults, key: "lib")
        #expect(persistence.load() == ScriptLibraryState())
    }

    @Test("round-trips a saved library")
    func roundTrips() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let persistence = UserDefaultsScriptPersistence(defaults: defaults, key: "lib")
        let a = Script(title: "A", body: "alpha")
        let state = ScriptLibraryState(scripts: [a], selectedID: a.id)
        persistence.save(state)
        #expect(persistence.load() == state)
    }
}
