import Testing
import Foundation
@testable import EyelineKit

@Suite("Script models")
struct ScriptModelTests {

    @Test("Script round-trips through JSON")
    func scriptRoundTrips() throws {
        let s = Script(title: "Hello", body: "World")
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(Script.self, from: data)
        #expect(decoded == s)
    }

    @Test("library state round-trips through JSON")
    func stateRoundTrips() throws {
        let s = Script(title: "Hello", body: "World")
        let state = ScriptLibraryState(scripts: [s], selectedID: s.id)
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(ScriptLibraryState.self, from: data)
        #expect(decoded == state)
    }

    @Test("default empty state has no scripts and no selection")
    func emptyDefault() {
        let state = ScriptLibraryState()
        #expect(state.scripts.isEmpty)
        #expect(state.selectedID == nil)
    }
}
