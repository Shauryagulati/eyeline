import AppKit
import EyelineKit
import KeyboardShortcuts

// Every AppKit app-delegate callback (and our menu actions) runs on the main thread, so
// isolate the whole delegate to the main actor. This lets the @objc menu handlers call
// into the @MainActor NotchController without actor-isolation errors.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var notch: NotchController!
    private var hideItem: NSMenuItem!
    private var launchAtLoginItem: NSMenuItem!
    private var scriptLibrary: ScriptLibraryViewModel!
    private var scriptsWindow: ScriptsWindowController!
    private var settingsStore: SettingsStore!
    private var settingsViewModel: SettingsViewModel!
    private var settingsWindow: SettingsWindowController!
    private let aboutWindow = AboutWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        notch = NotchController()

        let store = ScriptStore(persistence: UserDefaultsScriptPersistence())
        let library = ScriptLibraryViewModel(store: store)
        library.onSelectedTextChange = { [weak notch] text in
            notch?.setText(text)
        }
        notch.setText(library.selectedScript?.body ?? "")
        self.scriptLibrary = library
        self.scriptsWindow = ScriptsWindowController(model: library, notch: notch)

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
        settingsVM.onModeChange = { [weak notch] newMode, confirm in
            guard let notch else { confirm(false); return }
            notch.applyMode(newMode, completion: confirm)
        }
        self.settingsViewModel = settingsVM
        self.settingsWindow = SettingsWindowController(model: settingsVM, notch: notch)

        // Restore the last-used scroll mode silently (first play acquires any permissions). After
        // setText above, so Voice mode tokenizes the right script.
        notch.restoreMode(s.mode)

        setUpStatusItem()
        setUpMainMenu()
        notch.show()

        seedDefaultShortcutsIfNeeded()
        KeyboardShortcuts.onKeyUp(for: .togglePlay) { [weak self] in self?.notch.togglePlay() }
        KeyboardShortcuts.onKeyUp(for: .restart) { [weak self] in self?.notch.restart() }
        KeyboardShortcuts.onKeyUp(for: .toggleHidden) { [weak self] in self?.toggleHidden() }
    }

    /// On first launch only, give the three commands sensible default global hotkeys so the app is
    /// useful out of the box (⌃⌥P play/pause, ⌃⌥R restart, ⌃⌥H hide/show). Gated by a UserDefaults
    /// flag so we never re-seed — and each binding is only filled if the user hasn't set their own,
    /// so we can't clobber a customization. ⌃⌥H makes "hide before Mission Control" one keystroke.
    private func seedDefaultShortcutsIfNeeded() {
        let seededKey = "eyeline.didSeedShortcuts"
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: seededKey) else { return }

        if KeyboardShortcuts.getShortcut(for: .togglePlay) == nil {
            KeyboardShortcuts.setShortcut(.init(.p, modifiers: [.control, .option]), for: .togglePlay)
        }
        if KeyboardShortcuts.getShortcut(for: .restart) == nil {
            KeyboardShortcuts.setShortcut(.init(.r, modifiers: [.control, .option]), for: .restart)
        }
        if KeyboardShortcuts.getShortcut(for: .toggleHidden) == nil {
            KeyboardShortcuts.setShortcut(.init(.h, modifiers: [.control, .option]), for: .toggleHidden)
        }
        defaults.set(true, forKey: seededKey)
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let icon = NSImage(systemSymbolName: "text.aligncenter", accessibilityDescription: "Eyeline")
        // Template image → the menu bar tints it for light/dark + highlight like a native item.
        icon?.isTemplate = true
        statusItem.button?.image = icon

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

        let scriptsItem = NSMenuItem(
            title: "Scripts…", action: #selector(openScripts), keyEquivalent: "")
        scriptsItem.target = self
        menu.addItem(scriptsItem)

        // ⌘, is the conventional Settings shortcut; it fires while the menu is open or the app is
        // foreground (a config window is up). The menu also displays it as a native affordance.
        let settingsItem = NSMenuItem(
            title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let launchAtLoginItem = NSMenuItem(
            title: "Open at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        self.launchAtLoginItem = launchAtLoginItem

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(
            title: "About Eyeline", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem(
            title: "Quit Eyeline",
            action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.delegate = self   // so the Open-at-Login checkmark refreshes each time the menu opens
        statusItem.menu = menu
    }

    /// Refresh state that can change outside the menu before it's shown — currently the
    /// Open-at-Login checkmark (the OS, or the Settings toggle, may have changed it).
    func menuNeedsUpdate(_ menu: NSMenu) {
        launchAtLoginItem.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    /// The app is LSUIElement with no menu bar of its own — but it flips to `.regular` while the
    /// Scripts/Settings windows are open, and a SwiftUI text editor's Cut/Copy/Paste/Undo/Select All
    /// route through the standard Edit-menu key equivalents to the first responder. Without a main
    /// menu those keystrokes do nothing in the Scripts editor. This builds a minimal native menu:
    /// an app menu (so the bar reads correctly when active) and the Edit menu that does the work.
    private func setUpMainMenu() {
        let mainMenu = NSMenu()

        // App menu — fills the bold app-name slot so the active menu bar looks native.
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        let aboutItem = NSMenuItem(title: "About Eyeline", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        appMenu.addItem(aboutItem)
        appMenu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(
            title: "Quit Eyeline", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // Edit menu — nil targets route each command to the first responder (the focused text view).
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }

    // Targets set explicitly on the items above so they never grey out — a non-activating
    // panel means there's no key window to anchor the responder chain.
    @objc private func togglePlay() { notch.togglePlay() }
    @objc private func restart() { notch.restart() }

    @objc private func toggleHidden() {
        let visible = notch.toggleVisible()
        hideItem.title = visible ? "Hide Eyeline" : "Show Eyeline"
    }

    @objc private func openScripts() {
        scriptsWindow.show()
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }

    @objc private func openAbout() {
        aboutWindow.show()
    }

    @objc private func toggleLaunchAtLogin() {
        let result = LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
        launchAtLoginItem.state = result ? .on : .off
        // Keep the Settings toggle in sync if that window happens to be open.
        settingsViewModel?.refreshLaunchAtLogin()
    }
}
