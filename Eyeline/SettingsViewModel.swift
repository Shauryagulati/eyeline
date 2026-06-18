import SwiftUI
import EyelineKit

/// Bridges the pure `SettingsStore` to SwiftUI and notifies the notch when a value changes.
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var speed: Double
    @Published var fontSize: Double
    @Published var widthPreset: WidthPreset
    @Published var mode: ScrollMode
    /// Mirrors the OS login-item state (SMAppService), not the persisted Settings blob. Re-read from
    /// the OS whenever the Settings window appears so it stays truthful if changed elsewhere.
    @Published var launchAtLogin: Bool

    private let store: SettingsStore

    /// Wired in AppDelegate to the NotchController apply methods.
    var onSpeedChange: ((Double) -> Void)?
    var onFontSizeChange: ((Double) -> Void)?
    var onWidthChange: ((Double) -> Void)?   // passes points
    /// Mode change is async: the controller may need to acquire permissions first. It calls back
    /// with `true` if the mode took, `false` if it was rejected (so we revert the picker).
    var onModeChange: ((ScrollMode, @escaping (Bool) -> Void) -> Void)?

    init(store: SettingsStore) {
        self.store = store
        self.speed = store.settings.speed
        self.fontSize = store.settings.fontSize
        self.widthPreset = store.settings.widthPreset
        self.mode = store.settings.mode
        self.launchAtLogin = LaunchAtLogin.isEnabled
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

    /// Write the OS login-item state, then reflect what actually took (the OS can reject the change).
    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = LaunchAtLogin.setEnabled(enabled)
    }

    /// Re-read the OS login-item state — called when the Settings window appears, so a change made
    /// from the menu bar (or System Settings) is reflected.
    func refreshLaunchAtLogin() {
        launchAtLogin = LaunchAtLogin.isEnabled
    }

    func setMode(_ m: ScrollMode) {
        let previous = mode
        guard m != previous else { return }
        mode = m   // optimistic: the picker moves immediately…
        onModeChange?(m) { [weak self] success in
            guard let self else { return }
            if success {
                self.store.setMode(m)
            } else {
                self.mode = previous   // …but snaps back if the mode was rejected (M2)
            }
        }
    }
}
