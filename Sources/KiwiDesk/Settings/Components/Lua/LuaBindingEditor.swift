import KiwiDeskCore
import SwiftUI

/// Opens a Lua binding's body in the editor popover, keyed by the
/// binding's id (gui.md, #843).
struct LuaEditRequest: Identifiable, Equatable {
    let id: UUID
}

/// A Lua binding's body in Settings ▸ Lua's own editor (#2544 ▸
/// Ruling). Done (⌘Return) and a click away write the draft; Cancel
/// (Escape) drops the edit.
struct LuaBindingEditor: View {
    let title: String
    /// What VoiceOver calls the body.
    let spokenName: String
    let seed: String
    let write: (String) -> Void
    let dismiss: () -> Void

    @State private var text: String
    @State private var settled = false

    init(
        title: String,
        spokenName: String,
        seed: String,
        write: @escaping (String) -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.title = title
        self.spokenName = spokenName
        self.seed = seed
        self.write = write
        self.dismiss = dismiss
        _text = State(initialValue: seed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            LuaSourceEditor(text: $text, spokenName: spokenName)
                .frame(minHeight: 150)
            HStack {
                Spacer()
                Button(L("footer.cancel", "Cancel"), action: cancel)
                    .settingsActionButton()
                    .keyboardShortcut(.cancelAction)
                Button(L("common.done", "Done"), action: done)
                    .kiwiProminentButton()
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(12)
        .frame(width: 460)
        // A click away keeps the edit: only Cancel drops it.
        .onDisappear(perform: keep)
    }

    private func keep() {
        guard !settled else { return }
        settled = true
        if text != seed { write(text) }
    }

    private func done() {
        keep()
        dismiss()
    }

    private func cancel() {
        settled = true
        dismiss()
    }
}

/// How a Lua body reads in its row (#2544): one line edits in the
/// field; more read as their first line and a count.
enum LuaBodyShape {
    static func isMultiline(_ lua: String) -> Bool {
        lua.trimmingCharacters(in: .newlines).contains("\n")
    }

    static func firstLine(_ lua: String) -> String {
        lua.trimmingCharacters(in: .newlines)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .first.map(String.init) ?? ""
    }

    static func lineCount(_ lua: String) -> Int {
        lua.trimmingCharacters(in: .newlines)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .count
    }
}
