import SwiftUI
import EyelineKit

struct ScriptsView: View {
    @ObservedObject var model: ScriptLibraryViewModel

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(
                get: { model.selectedID },
                set: { if let id = $0 { model.select(id) } }
            )) {
                ForEach(model.scripts) { script in
                    Text(script.title.isEmpty ? "Untitled" : script.title)
                        .tag(script.id)
                }
            }
            .frame(minWidth: 200)
            .toolbar {
                ToolbarItem {
                    Button { model.add() } label: { Image(systemName: "plus") }
                        .help("New script")
                }
            }
        } detail: {
            if let script = model.selectedScript {
                ScriptEditor(
                    script: script,
                    onChange: { title, body in
                        model.update(id: script.id, title: title, body: body)
                    },
                    onDelete: { model.delete(id: script.id) }
                )
                .id(script.id)   // rebuild editor @State when the selection changes
            } else {
                Text("No script selected")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 680, minHeight: 440)
    }
}

private struct ScriptEditor: View {
    let script: Script
    let onChange: (String, String) -> Void
    let onDelete: () -> Void

    @State private var title: String
    @State private var bodyText: String

    init(script: Script,
         onChange: @escaping (String, String) -> Void,
         onDelete: @escaping () -> Void) {
        self.script = script
        self.onChange = onChange
        self.onDelete = onDelete
        _title = State(initialValue: script.title)
        _bodyText = State(initialValue: script.body)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.headline)
                .onChange(of: title) { _, newValue in onChange(newValue, bodyText) }

            TextEditor(text: $bodyText)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(.textBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.separatorColor)))
                .onChange(of: bodyText) { _, newValue in onChange(title, newValue) }

            HStack {
                Spacer()
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .padding()
    }
}
