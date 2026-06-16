import SwiftUI
import EyelineKit

/// Bridges the pure `ScriptStore` to SwiftUI and notifies the teleprompter when the selected
/// script's text changes (either by switching selection or editing the current body).
@MainActor
final class ScriptLibraryViewModel: ObservableObject {
    @Published private(set) var scripts: [Script]
    @Published private(set) var selectedID: UUID?

    private let store: ScriptStore

    /// Called with the selected script's body whenever it changes. Wired to the notch in AppDelegate.
    var onSelectedTextChange: ((String) -> Void)?

    init(store: ScriptStore) {
        self.store = store
        self.scripts = store.scripts
        self.selectedID = store.selectedID
    }

    var selectedScript: Script? {
        guard let selectedID else { return nil }
        return scripts.first { $0.id == selectedID }
    }

    func select(_ id: UUID) {
        store.select(id: id)
        sync()
    }

    func add() {
        store.add(title: "Untitled", body: "")
        sync()
    }

    func update(id: UUID, title: String, body: String) {
        store.update(id: id, title: title, body: body)
        sync()
    }

    func delete(id: UUID) {
        store.delete(id: id)
        sync()
    }

    private func sync() {
        scripts = store.scripts
        selectedID = store.selectedID
        onSelectedTextChange?(selectedScript?.body ?? "")
    }
}
