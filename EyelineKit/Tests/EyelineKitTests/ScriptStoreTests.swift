import Testing
import Foundation
@testable import EyelineKit

@Suite("ScriptStore")
struct ScriptStoreTests {

    @Test("seeds a default script on an empty store")
    func seedsDefault() {
        let store = ScriptStore(persistence: InMemoryScriptPersistence())
        #expect(store.scripts.count == 1)
        #expect(store.selectedScript != nil)
        #expect(store.selectedID == store.scripts.first?.id)
    }

    @Test("loads existing scripts without reseeding")
    func loadsExisting() {
        let a = Script(title: "A", body: "alpha")
        let b = Script(title: "B", body: "beta")
        let backing = InMemoryScriptPersistence(
            state: ScriptLibraryState(scripts: [a, b], selectedID: b.id))
        let store = ScriptStore(persistence: backing)
        #expect(store.scripts.map(\.title) == ["A", "B"])
        #expect(store.selectedID == b.id)
    }

    @Test("add appends, selects, and persists")
    func addSelectsAndPersists() {
        let backing = InMemoryScriptPersistence()
        let store = ScriptStore(persistence: backing)     // seeds 1 + saves once
        let savesAfterSeed = backing.saveCount
        let added = store.add(title: "New", body: "x")
        #expect(store.scripts.last?.id == added.id)
        #expect(store.selectedID == added.id)
        #expect(backing.saveCount == savesAfterSeed + 1)
        #expect(backing.state.scripts.contains(added))
    }

    @Test("update edits the matching script")
    func updateEdits() {
        let a = Script(title: "A", body: "alpha")
        let store = ScriptStore(persistence:
            InMemoryScriptPersistence(state: ScriptLibraryState(scripts: [a], selectedID: a.id)))
        store.update(id: a.id, title: "A2", body: "alpha2")
        #expect(store.selectedScript?.title == "A2")
        #expect(store.selectedScript?.body == "alpha2")
    }

    @Test("deleting the selected script reselects another")
    func deleteSelectedReselects() {
        let a = Script(title: "A", body: "alpha")
        let b = Script(title: "B", body: "beta")
        let store = ScriptStore(persistence:
            InMemoryScriptPersistence(state: ScriptLibraryState(scripts: [a, b], selectedID: a.id)))
        store.delete(id: a.id)
        #expect(store.scripts.map(\.title) == ["B"])
        #expect(store.selectedID == b.id)
    }

    @Test("deleting the last script clears the selection")
    func deleteLastClearsSelection() {
        let a = Script(title: "A", body: "alpha")
        let store = ScriptStore(persistence:
            InMemoryScriptPersistence(state: ScriptLibraryState(scripts: [a], selectedID: a.id)))
        store.delete(id: a.id)
        #expect(store.scripts.isEmpty)
        #expect(store.selectedID == nil)
        #expect(store.selectedScript == nil)
    }

    @Test("select only changes to known ids")
    func selectKnownOnly() {
        let a = Script(title: "A", body: "alpha")
        let b = Script(title: "B", body: "beta")
        let store = ScriptStore(persistence:
            InMemoryScriptPersistence(state: ScriptLibraryState(scripts: [a, b], selectedID: a.id)))
        store.select(id: b.id)
        #expect(store.selectedID == b.id)
        store.select(id: UUID())          // unknown id is ignored
        #expect(store.selectedID == b.id)
    }

    @Test("heals a dangling selection on load")
    func healsDanglingSelection() {
        let a = Script(title: "A", body: "alpha")
        let store = ScriptStore(persistence:
            InMemoryScriptPersistence(state: ScriptLibraryState(scripts: [a], selectedID: UUID())))
        #expect(store.selectedID == a.id)
    }
}
