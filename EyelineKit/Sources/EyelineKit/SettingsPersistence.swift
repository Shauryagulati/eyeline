import Foundation

/// Frozen seam between the settings store and where settings physically live.
/// Tests inject `InMemorySettingsPersistence`; the app injects `UserDefaultsSettingsPersistence`.
public protocol SettingsPersistence: AnyObject {
    func load() -> Settings
    func save(_ settings: Settings)
}

/// In-memory backend for tests. Records the last saved value and how many times save ran.
public final class InMemorySettingsPersistence: SettingsPersistence {
    public private(set) var settings: Settings
    public private(set) var saveCount = 0

    public init(settings: Settings = .defaults) {
        self.settings = settings
    }

    public func load() -> Settings { settings }

    public func save(_ settings: Settings) {
        self.settings = settings
        saveCount += 1
    }
}
