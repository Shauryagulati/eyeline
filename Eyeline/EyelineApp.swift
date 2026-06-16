import SwiftUI

@main
struct EyelineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // No main window. Everything lives in the status item + the notch panel.
        Settings { EmptyView() }
    }
}
