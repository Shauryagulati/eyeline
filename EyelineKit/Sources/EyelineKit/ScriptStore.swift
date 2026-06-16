import Foundation

/// The script library brain: holds scripts + the current selection, mutates them, and persists
/// every change through the injected `ScriptPersistence`. UI-framework-free so it tests headlessly.
public final class ScriptStore {
    public private(set) var scripts: [Script]
    public private(set) var selectedID: UUID?

    private let persistence: ScriptPersistence

    public init(persistence: ScriptPersistence) {
        self.persistence = persistence
        let loaded = persistence.load()

        if loaded.scripts.isEmpty {
            // First run: seed one welcome script so the teleprompter has something to show.
            let sample = Script(title: "Welcome to Eyeline", body: ScriptStore.sampleBody)
            self.scripts = [sample]
            self.selectedID = sample.id
            persistence.save(ScriptLibraryState(scripts: scripts, selectedID: selectedID))
        } else {
            self.scripts = loaded.scripts
            // Heal a selection that points at a script that no longer exists.
            if let sel = loaded.selectedID, loaded.scripts.contains(where: { $0.id == sel }) {
                self.selectedID = sel
            } else {
                self.selectedID = loaded.scripts.first?.id
            }
        }
    }

    public var selectedScript: Script? {
        guard let selectedID else { return nil }
        return scripts.first { $0.id == selectedID }
    }

    @discardableResult
    public func add(title: String, body: String) -> Script {
        let script = Script(title: title, body: body)
        scripts.append(script)
        selectedID = script.id
        persist()
        return script
    }

    public func update(id: UUID, title: String, body: String) {
        guard let idx = scripts.firstIndex(where: { $0.id == id }) else { return }
        scripts[idx].title = title
        scripts[idx].body = body
        persist()
    }

    public func delete(id: UUID) {
        scripts.removeAll { $0.id == id }
        if selectedID == id {
            selectedID = scripts.first?.id
        }
        persist()
    }

    public func select(id: UUID) {
        guard scripts.contains(where: { $0.id == id }) else { return }
        selectedID = id
        persist()
    }

    private func persist() {
        persistence.save(ScriptLibraryState(scripts: scripts, selectedID: selectedID))
    }

    static let sampleBody = """
    Welcome to Eyeline.

    This is your teleprompter. Edit this script, or add your own from the Scripts window.

    Look straight at your camera and read naturally — the words scroll right beneath your notch.
    """
}
