import SwiftUI
import AppKit
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

            ScriptTextView(text: $bodyText, font: .systemFont(ofSize: 14))
                .clipShape(RoundedRectangle(cornerRadius: 6))
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

/// AppKit-backed multiline editor for the script body. SwiftUI's `TextEditor`, when hosted in a
/// plain AppKit `NSWindow` (rather than a SwiftUI scene), doesn't reliably become the AppKit first
/// responder that the standard Edit menu validates against — so Cut/Copy/Paste/Select All silently
/// no-op even though typing works. Wrapping a real `NSTextView` puts a genuine responder in the
/// chain, so the Edit menu (and ⌘C/⌘X/⌘V/⌘A) work, and it brings native undo for free.
private struct ScriptTextView: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        guard let textView = scroll.documentView as? NSTextView else { return scroll }
        textView.delegate = context.coordinator
        textView.font = font
        textView.isRichText = false
        textView.allowsUndo = true
        // Plain-text editing for scripts — straight quotes/dashes, no autocorrect mangling.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.drawsBackground = false              // SwiftUI draws the rounded background behind us
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.string = text
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NSTextView else { return }
        // Only overwrite on an *external* change (e.g. switching scripts); never while the user is
        // typing, or we'd stomp the insertion point.
        if textView.string != text { textView.string = text }
        textView.font = font
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let parent: ScriptTextView
        init(_ parent: ScriptTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
