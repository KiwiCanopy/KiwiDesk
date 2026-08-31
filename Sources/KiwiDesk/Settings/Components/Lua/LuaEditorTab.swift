import KiwiDeskCore
import SwiftUI

/// Raw Lua configuration editor tab and adoption interface (#68 §3.12).
struct LuaEditorTab: View {
    @ObservedObject var model: SettingsModel
    @State private var confirmingAdopt = false

    private let adoptGreen = Color(
        red: 0.16,
        green: 0.45,
        blue: 0.24
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            LuaSourceEditor(text: $model.luaSource)
        }
        .padding(16)
        .confirmationDialog(
            L(
                "lua_editor.adopt.title",
                "%1$@ this config into the visual editor?",
                L("lua_editor.adopt", "Adopt")
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

    /// Adoption confirmation message reflecting dirty state (#515).
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
                + "backup — but %1$@ reads that file from disk, "
                + "so the edits you haven't saved are dropped.",
            L("lua_editor.adopt", "Adopt")
        )
    }

    @ViewBuilder private var header: some View {
        if model.forcedLuaEditor {
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
                .settingsActionButton()
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

    /// Adoption help description interpolating shortcut pane title
    /// (#515, #818).
    private var adoptHelpBody: String {
        L(
            "lua_editor.adopt_help.body",
            "Your init.lua isn't deleted: it's kept as a "
                + "commented-out backup in the new file. "
                + "Gaps, layouts, rules, and "
                + "keybindings are imported; a "
                + "shortcut that can't be read back "
                + "stays in the backup — re-add it in "
                + "\u{201C}%1$@\u{201D}.",
            SettingsDestination.shortcuts.title
        )
    }
}

/// Monospaced text editor wrapped around NSTextView (`gui.md`, #812).
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
        textView.setAccessibilityLabel("init.lua")
        return scroll
    }

    func updateNSView(
        _ scroll: NSScrollView,
        context: Context
    ) {
        guard
            let textView = scroll.documentView as? NSTextView
        else { return }
        textView.setAccessibilityLabel("init.lua")
        guard textView.string != text else { return }
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
