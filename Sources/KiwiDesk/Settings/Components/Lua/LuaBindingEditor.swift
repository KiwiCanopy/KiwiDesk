import KiwiDeskCore
import SwiftUI

/// Opens a Lua binding's body in the editor popover, keyed by the
/// binding's id (gui.md, #843).
struct LuaEditRequest: Identifiable, Equatable {
    let id: UUID
}

/// A Lua binding's body in Settings ▸ Lua's own editor (#2544 ▸
/// Ruling). The body writes the draft as it is typed, so Done
/// (⌘Return) and a click away leave the edit and no late write can
/// land after a Save or a Revert; Cancel (Escape) puts back the body
/// the row had when the editor opened, unless a Save or a Revert has
/// moved the draft since the editor last wrote it.
struct LuaBindingEditor: View {
    let title: String
    /// What VoiceOver calls the body.
    let spokenName: String
    @Binding var text: String
    let dismiss: () -> Void

    @State private var seed: String
    /// The body this editor last wrote into the draft.
    @State private var written: String

    init(
        title: String,
        spokenName: String,
        text: Binding<String>,
        dismiss: @escaping () -> Void
    ) {
        self.title = title
        self.spokenName = spokenName
        _text = text
        self.dismiss = dismiss
        _seed = State(initialValue: text.wrappedValue)
        _written = State(initialValue: text.wrappedValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            LuaSourceEditor(text: typed, spokenName: spokenName)
                .frame(minHeight: 150)
            HStack {
                Spacer()
                Button(L("footer.cancel", "Cancel"), action: cancel)
                    .settingsActionButton()
                    .keyboardShortcut(.cancelAction)
                Button(L("common.done", "Done"), action: dismiss)
                    .kiwiProminentButton()
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(12)
        .frame(width: 460)
    }

    private var typed: Binding<String> {
        Binding(
            get: { text },
            set: {
                written = $0
                text = $0
            }
        )
    }

    private func cancel() {
        if text == written { text = seed }
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
