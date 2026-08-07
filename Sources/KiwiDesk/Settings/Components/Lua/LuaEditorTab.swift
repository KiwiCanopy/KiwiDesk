import KiwiDeskCore
import SwiftUI

/// The integrated Lua editor. Shown when init.lua holds code
/// the visual editor can't represent (foreign code touching
/// managed vocabulary), or when the user opts to edit raw Lua.
/// Edits here write the whole file verbatim.
struct LuaEditorTab: View {
    @ObservedObject var model: SettingsModel
    @State private var confirmingAdopt = false

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
        } message: {
            Text(adoptMessage)
        }
    }

    /// Adopt is an eighth discard path (#515 review): it reads
    /// the original from **disk**, never `luaSource`, then
    /// reloads — so an unsaved buffer is dropped. It keeps its
    /// own dialog rather than stacking the shared discard gate
    /// on top (one gesture, one prompt), so that dialog has to
    /// say so itself. The adopt help's "Nothing is lost" is
    /// about the on-disk commented backup and was silently
    /// false for the buffer.
    private var adoptMessage: String {
        guard model.isDirty else {
            return L(
                "lua_editor.adopt.message",
                "Your current init.lua is kept as a "
                    + "commented-out backup."
            )
        }
        return L(
            "lua_editor.adopt.message_dirty",
            "Your current init.lua is kept as a commented-out "
                + "backup — but Adopt reads that file from disk, "
                + "so the edits you haven't saved are dropped."
        )
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
                HelpButton(explanation: adoptHelpBody)
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
                // The mirror image of "Edit init.lua directly":
                // `reload()` re-seeds from disk, so unsaved Lua
                // is dropped. Same gate (#515).
                Button(
                    L(
                        "lua_editor.back_to_visual",
                        "Back to visual editor"
                    )
                ) {
                    model.discardingEdits(
                        message: L(
                            "discard.visual_editor.message",
                            "Leaving the raw editor reloads "
                                + "init.lua from disk, dropping "
                                + "the Lua you haven't saved."
                        ),
                        confirmLabel: L(
                            "discard.visual_editor.confirm",
                            "Discard & leave"
                        )
                    ) {
                        model.showLuaEditor = false
                        model.reload()
                    }
                }
                .buttonStyle(.bordered)
                .neutralButtonLabel()
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

    private var adoptHelpBody: String {
        L(
            "lua_editor.adopt_help.body",
            // Was "Nothing is lost: …", which is true of the
            // FILE and false of an unsaved editor buffer — and
            // this popover sits beside the Adopt dialog that now
            // says the opposite when dirty (#515 review).
            "Your init.lua isn't deleted: it's kept as a "
                + "commented-out backup in the new file. "
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
