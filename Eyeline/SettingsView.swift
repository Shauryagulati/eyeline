import SwiftUI
import EyelineKit
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        Form {
            Section("Scrolling") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Speed: \(Int(model.speed)) pt/s")
                    Slider(
                        value: Binding(get: { model.speed }, set: { model.setSpeed($0) }),
                        in: Settings.speedRange, step: 1)
                }
            }

            Section("Appearance") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Font size: \(Int(model.fontSize)) pt")
                    Slider(
                        value: Binding(get: { model.fontSize }, set: { model.setFontSize($0) }),
                        in: Settings.fontSizeRange, step: 1)
                }
                Picker("Width", selection: Binding(
                    get: { model.widthPreset }, set: { model.setWidthPreset($0) })) {
                    ForEach(WidthPreset.allCases, id: \.self) { preset in
                        Text(preset.label).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Shortcuts") {
                KeyboardShortcuts.Recorder("Play / Pause:", name: .togglePlay)
                KeyboardShortcuts.Recorder("Restart:", name: .restart)
                KeyboardShortcuts.Recorder("Hide / Show:", name: .toggleHidden)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}
