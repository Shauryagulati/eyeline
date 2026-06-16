import SwiftUI

@main
struct EyelineApp: App {
    var body: some Scene {
        // No main window — Eyeline is a menu-bar-only app (LSUIElement).
        // The status item + notch panel arrive in the next steps.
        Settings { EmptyView() }
    }
}
