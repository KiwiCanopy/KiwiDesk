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
    /// Always drawn, so an empty binding's editor still names what
    /// it edits (#2688).
    let title: String
    /// What VoiceOver calls the body.
    let spokenName: String
    /// Drawn in the editor while the body is empty, never written.
    let placeholder: String
    @Binding var text: String
    let dismiss: () -> Void

    @State private var seed: String
    /// The body this editor last wrote into the draft.
    @State private var written: String

    init(
        title: String,
        spokenName: String,
        placeholder: String,
        text: Binding<String>,
        dismiss: @escaping () -> Void
    ) {
        self.title = title
        self.spokenName = spokenName
        self.placeholder = placeholder
        _text = text
        self.dismiss = dismiss
        _seed = State(initialValue: text.wrappedValue)
        _written = State(initialValue: text.wrappedValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(SettingsTheme.ink)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityAddTraits(.isHeader)
            LuaSourceEditor(
                text: typed,
                spokenName: spokenName,
                placeholder: placeholder,
                takesFocus: true,
                inset: Self.textInset
            )
            .frame(minHeight: 150)
            .overlay(alignment: .topLeading) { placeholderText }
            // The container's edge, so the box reads as one (#2688).
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        SettingsTheme.hairline,
                        lineWidth: SettingsTheme.containerStroke
                    )
            )
            HStack {
                actionsLink
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

    /// The text's room inside the bordered box (#2688).
    static let textInset = NSSize(width: 6, height: 6)

    @ViewBuilder private var placeholderText: some View {
        if text.isEmpty {
            Text(placeholder)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(SettingsTheme.ink3)
                // Past NSTextView's 5 pt line fragment padding.
                .padding(.leading, Self.textInset.width + 5)
                .padding(.top, Self.textInset.height)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// The drawer's actions page, one click from the body (#2688).
    private var actionsLink: some View {
        Button(action: ActionsListLink.open) {
            Text(L("shortcuts.lua.actions_short", "Actions list"))
                .underline()
        }
        .buttonStyle(.plain)
        .font(.caption)
        .foregroundStyle(SettingsTheme.ink2)
        .linkHover()
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
