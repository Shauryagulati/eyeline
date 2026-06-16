import AppKit

// Every AppKit app-delegate callback (and our menu actions) runs on the main thread, so
// isolate the whole delegate to the main actor. This lets the @objc menu handlers call
// into the @MainActor NotchController without actor-isolation errors.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var notch: NotchController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        notch = NotchController()
        setUpStatusItem()
        notch.show()
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "text.aligncenter", accessibilityDescription: "Eyeline")

        let menu = NSMenu()

        let playItem = NSMenuItem(
            title: "Play / Pause", action: #selector(togglePlay), keyEquivalent: "p")
        playItem.target = self
        menu.addItem(playItem)

        let restartItem = NSMenuItem(
            title: "Restart", action: #selector(restart), keyEquivalent: "r")
        restartItem.target = self
        menu.addItem(restartItem)

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
}
