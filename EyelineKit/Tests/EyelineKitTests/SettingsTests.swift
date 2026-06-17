import Foundation
import Testing
@testable import EyelineKit

@Suite("Settings")
struct SettingsTests {
    @Test("width presets map to ascending point widths")
    func widthPoints() {
        #expect(WidthPreset.standard.points == 360)
        #expect(WidthPreset.wide.points == 480)
        #expect(WidthPreset.ultraWide.points == 600)
    }

    @Test("every preset has a non-empty label and is enumerable")
    func labels() {
        #expect(WidthPreset.allCases.count == 3)
        #expect(WidthPreset.allCases.allSatisfy { !$0.label.isEmpty })
    }

    @Test("defaults are speed 30, font 22, standard width")
    func defaults() {
        #expect(Settings.defaults.speed == 30)
        #expect(Settings.defaults.fontSize == 22)
        #expect(Settings.defaults.widthPreset == .standard)
    }

    @Test("clamp pins values into range")
    func clamp() {
        #expect(Settings.clampSpeed(5) == Settings.speedRange.lowerBound)
        #expect(Settings.clampSpeed(45) == 45)
        #expect(Settings.clampSpeed(999) == Settings.speedRange.upperBound)
        #expect(Settings.clampFontSize(2) == Settings.fontSizeRange.lowerBound)
        #expect(Settings.clampFontSize(20) == 20)
        #expect(Settings.clampFontSize(999) == Settings.fontSizeRange.upperBound)
    }

    @Test("init clamps out-of-range inputs")
    func initClamps() {
        let s = Settings(speed: 999, fontSize: 1, widthPreset: .wide)
        #expect(s.speed == Settings.speedRange.upperBound)
        #expect(s.fontSize == Settings.fontSizeRange.lowerBound)
        #expect(s.widthPreset == .wide)
    }

    @Test("round-trips through Codable")
    func codable() throws {
        let original = Settings(speed: 42, fontSize: 28, widthPreset: .ultraWide)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)
        #expect(decoded == original)
    }
}
