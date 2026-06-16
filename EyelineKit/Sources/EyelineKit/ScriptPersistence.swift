import Foundation

/// Frozen seam between the script store and wherever the data physically lives.
/// Tests inject `InMemoryScriptPersistence`; the app injects `UserDefaultsScriptPersistence`.
public protocol ScriptPersistence: AnyObject {
    func load() -> ScriptLibraryState
    func save(_ state: ScriptLibraryState)
}

/// In-memory backend for tests. Records the last saved state and how many times save ran.
public final class InMemoryScriptPersistence: ScriptPersistence {
    public private(set) var state: ScriptLibraryState
    public private(set) var saveCount = 0

    public init(state: ScriptLibraryState = ScriptLibraryState()) {
        self.state = state
    }

    public func load() -> ScriptLibraryState { state }

    public func save(_ state: ScriptLibraryState) {
        self.state = state
        saveCount += 1
    }
}
