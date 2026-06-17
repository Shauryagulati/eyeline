import Foundation

/// Persists settings as a single JSON blob in UserDefaults. Foundation-only, so it tests headlessly.
public final class UserDefaultsSettingsPersistence: SettingsPersistence {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "eyeline.settings") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> Settings {
        guard let data = defaults.data(forKey: key) else { return .defaults }
        return (try? JSONDecoder().decode(Settings.self, from: data)) ?? .defaults
    }

    public func save(_ settings: Settings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
