import AppKit
import EyelineKit

// Every AppKit app-delegate callback (and our menu actions) runs on the main thread, so
// isolate the whole delegate to the main actor. This lets the @objc menu handlers call
// into the @MainActor NotchController without actor-isolation errors.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var notch: NotchController!
    private var voiceItem: NSMenuItem!
    private var hideItem: NSMenuItem!
    private var scriptLibrary: ScriptLibraryViewModel!
    private var scriptsWindow: ScriptsWindowController!
    private var settingsStore: SettingsStore!
    private var settingsViewModel: SettingsViewModel!
    private var settingsWindow: SettingsWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        notch = NotchController()

        let store = ScriptStore(persistence: UserDefaultsScriptPersistence())
        let library = ScriptLibraryViewModel(store: store)
        library.onSelectedTextChange = { [weak notch] text in
            notch?.setText(text)
        }
        notch.setText(library.selectedScript?.body ?? "")
        self.scriptLibrary = library
        self.scriptsWindow = ScriptsWindowController(model: library)

        let settingsStore = SettingsStore(persistence: UserDefaultsSettingsPersistence())
        self.settingsStore = settingsStore
        let s = settingsStore.settings
        notch.setSpeed(s.speed)
        notch.setFontSize(s.fontSize)
        notch.setWidth(s.widthPreset.points)

        let settingsVM = SettingsViewModel(store: settingsStore)
        settingsVM.onSpeedChange = { [weak notch] in notch?.setSpeed($0) }
        settingsVM.onFontSizeChange = { [weak notch] in notch?.setFontSize($0) }
        settingsVM.onWidthChange = { [weak notch] in notch?.setWidth($0) }
        self.settingsViewModel = settingsVM
        self.settingsWindow = SettingsWindowController(model: settingsVM)

        setUpStatusItem()
        notch.show()
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "text.aligncenter", accessibilityDescription: "Eyeline")

        let menu = NSMenu()

        let playItem = NSMenuItem(
            title: "Play / Pause", action: #selector(togglePlay), keyEquivalent: "")
        playItem.target = self
        menu.addItem(playItem)

        let restartItem = NSMenuItem(
            title: "Restart", action: #selector(restart), keyEquivalent: "")
        restartItem.target = self
        menu.addItem(restartItem)

        let hideItem = NSMenuItem(
            title: "Hide Eyeline", action: #selector(toggleHidden), keyEquivalent: "")
        hideItem.target = self
        menu.addItem(hideItem)
        self.hideItem = hideItem

        let voiceItem = NSMenuItem(
            title: "Voice-gated scrolling", action: #selector(toggleVoiceGated), keyEquivalent: "")
        voiceItem.target = self
        voiceItem.state = .off
        menu.addItem(voiceItem)
        self.voiceItem = voiceItem

        let scriptsItem = NSMenuItem(
            title: "Scripts…", action: #selector(openScripts), keyEquivalent: "")
        scriptsItem.target = self
        menu.addItem(scriptsItem)

        let settingsItem = NSMenuItem(
            title: "Settings…", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Eyeline",
            action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    // Targets set explicitly on the items above so they never grey out — a non-activating
    // panel means there's no key window to anchor the responder chain.
    @objc private func togglePlay() { notch.togglePlay() }
    @objc private func restart() { notch.restart() }

    @objc private func toggleHidden() {
        let visible = notch.toggleVisible()
        hideItem.title = visible ? "Hide Eyeline" : "Show Eyeline"
    }

    @objc private func toggleVoiceGated() {
        let on = (voiceItem.state == .off)
        voiceItem.state = on ? .on : .off
        notch.setVoiceGated(on)
    }

    @objc private func openScripts() {
        scriptsWindow.show()
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }
}
