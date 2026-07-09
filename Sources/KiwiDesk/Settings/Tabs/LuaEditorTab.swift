import KiwiDeskCore
import SwiftUI

/// The integrated Lua editor. Shown when init.lua holds code
/// the visual editor can't represent (foreign code touching
/// managed vocabulary), or when the user opts to edit raw Lua
/// (05_GUI_Concept §2). Edits here write the whole file verbatim.
struct LuaEditorTab: View {
    @ObservedObject var model: SettingsModel
    @State private var confirmingAdopt = false
    @State private var showAdoptHelp = false
    @State private var helpHovering = false

    /// A muted, darker green so the action reads as inviting
    /// without shouting over the footer's Save button.
    private let adoptGreen = Color(
        red: 0.16,
        green: 0.45,
        blue: 0.24
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            // Dirty tracking rides `luaSource`'s own didSet
            // in the model — a live baseline comparison, not
            // a latched flag.
            LuaSourceEditor(text: $model.luaSource)
        }
        .padding(16)
        .confirmationDialog(
            L(
                "lua_editor.adopt.title",
                "Adopt this config into the visual editor?"
            ),
            isPresented: $confirmingAdopt,
            titleVisibility: .visible
        ) {
            Button(L("lua_editor.adopt", "Adopt")) {
                model.adoptIntoGui()
            }
            Button(L("footer.cancel", "Cancel"), role: .cancel) {}
        }
    }

    @ViewBuilder private var header: some View {
        if model.forcedLuaEditor {
            // The Adopt action lives with the content it
            // migrates (#68 §3.12) — it is not a save verb,
            // so it left the footer.
            HStack(spacing: 8) {
                Label {
                    Text(foreignCodeCaption)
                } icon: {
                    Image(systemName: "curlybraces")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                Spacer()
                adoptButton
                helpButton
            }
        } else {
            HStack {
                Text(
                    L(
                        "lua_editor.editing_directly",
                        "Editing init.lua directly."
                    )
                )
                .foregroundStyle(.secondary)
                Spacer()
                Button(
                    L(
                        "lua_editor.back_to_visual",
                        "Back to visual editor"
                    )
                ) {
                    model.showLuaEditor = false
                    model.reload()
                }
            }
            .font(.callout)
        }
    }

    private var foreignCodeCaption: String {
        L(
            "lua_editor.foreign_code",
            "This init.lua contains hand-written "
                + "Lua, so the visual editor is "
                + "disabled to avoid overwriting "
                + "it."
        )
    }

    private var adoptButton: some View {
        Button {
            confirmingAdopt = true
        } label: {
            Label(
                L(
                    "lua_editor.adopt_into_visual",
                    "Adopt into Visual Editor…"
                ),
                systemImage: "wand.and.stars"
            )
        }
        .buttonStyle(.borderedProminent)
        .tint(adoptGreen)
    }

    private var helpButton: some View {
        Image(systemName: "questionmark.circle")
            .imageScale(.large)
            .foregroundStyle(
                helpHovering ? Color.accentColor : .secondary
            )
            .animation(
                .easeInOut(duration: 0.15),
                value: helpHovering
            )
            .onHover { hovering in
                helpHovering = hovering
                showAdoptHelp = hovering
            }
            .help(
                L(
                    "lua_editor.adopt_help",
                    "What happens to my current code?"
                )
            )
            .popover(
                isPresented: $showAdoptHelp,
                arrowEdge: .top
            ) {
                Text(adoptHelpBody)
                    .font(.callout)
                    .frame(width: 300)
                    .padding()
            }
    }

    private var adoptHelpBody: String {
        L(
            "lua_editor.adopt_help.body",
            "Nothing is lost: your current code isn't "
                + "deleted, it's kept as a "
                + "commented-out backup in init.lua. "
                + "Gaps, layouts, rules, and "
                + "keybindings are imported; a "
                + "shortcut that can't be read back "
                + "stays in the backup — re-add it in "
                + "the Shortcuts section."
        )
    }
}

/// A monospaced, scrollable text editor backed by NSTextView so
/// large configs stay responsive and tabs indent properly.
struct LuaSourceEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        guard let textView = scroll.documentView as? NSTextView
        else { return scroll }
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = .monospacedSystemFont(
            ofSize: 12,
            weight: .regular
        )
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.string = text
        return scroll
    }

    func updateNSView(
        _ scroll: NSScrollView,
        context: Context
    ) {
        guard
            let textView = scroll.documentView as? NSTextView,
            textView.string != text
        else { return }
        textView.string = text
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        private let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard
                let textView = notification.object
                    as? NSTextView
            else { return }
            text.wrappedValue = textView.string
        }
    }
}
