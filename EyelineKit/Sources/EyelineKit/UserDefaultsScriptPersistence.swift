import Foundation

/// Persists the library as a single JSON blob in UserDefaults. Foundation-only, so it lives in
/// EyelineKit and is testable headlessly with a throwaway suite.
public final class UserDefaultsScriptPersistence: ScriptPersistence {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "eyeline.scriptLibrary") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> ScriptLibraryState {
        guard let data = defaults.data(forKey: key) else { return ScriptLibraryState() }
        return (try? JSONDecoder().decode(ScriptLibraryState.self, from: data)) ?? ScriptLibraryState()
    }

    public func save(_ state: ScriptLibraryState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
    }
}
