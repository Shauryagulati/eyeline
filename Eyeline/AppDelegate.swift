import AppKit

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
        menu.addItem(NSMenuItem(
            title: "Quit Eyeline",
            action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }
}
