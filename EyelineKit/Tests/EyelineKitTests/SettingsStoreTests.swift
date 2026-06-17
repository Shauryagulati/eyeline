import Testing
@testable import EyelineKit

@Suite("SettingsStore")
struct SettingsStoreTests {
    @Test("loads defaults from an empty backend")
    func loadsDefaults() {
        let store = SettingsStore(persistence: InMemorySettingsPersistence())
        #expect(store.settings == Settings.defaults)
    }

    @Test("re-clamps out-of-range stored values on load")
    func reclampsOnLoad() {
        // A tampered/garbage persisted value decodes raw, then the store clamps it.
        let raw = Settings(speed: 30, fontSize: 22, widthPreset: .standard)
        let backend = InMemorySettingsPersistence(settings: raw)
        // Force an out-of-range value past the clamping init by mutating the struct directly.
        backend.save({ var s = raw; s.speed = 999; return s }())
        let store = SettingsStore(persistence: backend)
        #expect(store.settings.speed == Settings.speedRange.upperBound)
    }

    @Test("setSpeed clamps and persists")
    func setSpeed() {
        let backend = InMemorySettingsPersistence()
        let store = SettingsStore(persistence: backend)
        store.setSpeed(999)
        #expect(store.settings.speed == Settings.speedRange.upperBound)
        #expect(backend.load().speed == Settings.speedRange.upperBound)
    }

    @Test("setFontSize clamps and persists")
    func setFontSize() {
        let backend = InMemorySettingsPersistence()
        let store = SettingsStore(persistence: backend)
        store.setFontSize(2)
        #expect(store.settings.fontSize == Settings.fontSizeRange.lowerBound)
        #expect(backend.load().fontSize == Settings.fontSizeRange.lowerBound)
    }

    @Test("setWidthPreset persists")
    func setWidth() {
        let backend = InMemorySettingsPersistence()
        let store = SettingsStore(persistence: backend)
        store.setWidthPreset(.ultraWide)
        #expect(store.settings.widthPreset == .ultraWide)
        #expect(backend.load().widthPreset == .ultraWide)
    }

    @Test("setMode persists")
    func setMode() {
        let backend = InMemorySettingsPersistence()
        let store = SettingsStore(persistence: backend)
        store.setMode(.voice)
        #expect(store.settings.mode == .voice)
        #expect(backend.load().mode == .voice)
    }

    @Test("a persisted mode survives the load re-clamp")
    func modeSurvivesLoad() {
        // Regression: the load re-clamp must carry `mode` through, not silently reset it to .timed.
        let backend = InMemorySettingsPersistence(settings: Settings(mode: .loudness))
        let store = SettingsStore(persistence: backend)
        #expect(store.settings.mode == .loudness)
    }
}
