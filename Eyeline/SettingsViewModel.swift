import SwiftUI
import EyelineKit

/// Bridges the pure `SettingsStore` to SwiftUI and notifies the notch when a value changes.
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var speed: Double
    @Published var fontSize: Double
    @Published var widthPreset: WidthPreset

    private let store: SettingsStore

    /// Wired in AppDelegate to the NotchController apply methods.
    var onSpeedChange: ((Double) -> Void)?
    var onFontSizeChange: ((Double) -> Void)?
    var onWidthChange: ((Double) -> Void)?   // passes points

    init(store: SettingsStore) {
        self.store = store
        self.speed = store.settings.speed
        self.fontSize = store.settings.fontSize
        self.widthPreset = store.settings.widthPreset
    }

    func setSpeed(_ v: Double) {
        store.setSpeed(v)
        speed = store.settings.speed
        onSpeedChange?(speed)
    }

    func setFontSize(_ v: Double) {
        store.setFontSize(v)
        fontSize = store.settings.fontSize
        onFontSizeChange?(fontSize)
    }

    func setWidthPreset(_ p: WidthPreset) {
        store.setWidthPreset(p)
        widthPreset = store.settings.widthPreset
        onWidthChange?(widthPreset.points)
    }
}
