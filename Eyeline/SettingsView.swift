import SwiftUI
import EyelineKit
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        Form {
            Section("Scrolling") {
                VStack(alignment: .leading, spacing: 6) {
                    Picker("Mode", selection: Binding(
                        get: { model.mode }, set: { model.setMode($0) })) {
                        ForEach(ScrollMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(modeHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Speed: \(Int(model.speed)) pt/s")
                    Slider(
                        value: Binding(get: { model.speed }, set: { model.setSpeed($0) }),
                        in: Settings.speedRange, step: 1)
                }
                // Voice mode follows your speaking pace, so a constant speed doesn't apply.
                .disabled(model.mode == .voice)
                .opacity(model.mode == .voice ? 0.4 : 1)
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

    private var modeHint: String {
        switch model.mode {
        case .timed:    return "Scrolls at a constant speed."
        case .loudness: return "Scrolls while you’re speaking, pauses when you’re quiet."
        case .voice:    return "Follows your words and keeps your place centered. On-device, never recorded."
        }
    }
}
