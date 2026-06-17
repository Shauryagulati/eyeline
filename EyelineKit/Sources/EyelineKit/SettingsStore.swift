import Foundation

/// The settings brain: holds the current `Settings`, clamps every mutation, and persists each
/// change through the injected `SettingsPersistence`. UI-framework-free so it tests headlessly.
public final class SettingsStore {
    public private(set) var settings: Settings

    private let persistence: SettingsPersistence

    public init(persistence: SettingsPersistence) {
        self.persistence = persistence
        let loaded = persistence.load()
        // Re-clamp through the validating init in case stored values were out of range.
        self.settings = Settings(
            speed: loaded.speed, fontSize: loaded.fontSize,
            widthPreset: loaded.widthPreset, mode: loaded.mode)
    }

    public func setSpeed(_ v: Double) {
        settings.speed = Settings.clampSpeed(v)
        persist()
    }

    public func setFontSize(_ v: Double) {
        settings.fontSize = Settings.clampFontSize(v)
        persist()
    }

    public func setWidthPreset(_ preset: WidthPreset) {
        settings.widthPreset = preset
        persist()
    }

    public func setMode(_ mode: ScrollMode) {
        settings.mode = mode
        persist()
    }

    private func persist() { persistence.save(settings) }
}
