import SwiftUI

/// About-box content for Eyeline. Shown in a small titled window (`AboutWindowController`) rather
/// than the standard AppKit about panel: the LSUIElement app can then flip its activation policy
/// the same way the Scripts/Settings windows do (so the window reliably shows front-most), and the
/// copy stays fully under our control. Deliberately quiet — name, version, what it is, and that
/// it's free, MIT, and entirely on-device. No links: the project isn't public yet.
struct AboutView: View {
    private var versionLine: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        return "Version \(short)"
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)

            Text("Eyeline")
                .font(.system(size: 18, weight: .semibold, design: .rounded))

            Text(versionLine)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text("A teleprompter that docks under the notch, so you can read your script while holding eye contact.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Free & open-source · MIT Licensed\n100% on-device — no network, no accounts")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 300)
    }
}
