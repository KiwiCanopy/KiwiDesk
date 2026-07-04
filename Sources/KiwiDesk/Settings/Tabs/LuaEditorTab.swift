import KiwiDeskCore
import SwiftUI

/// The integrated Lua editor. Shown when init.lua holds code the
/// visual editor can't represent (foreign code outside the
/// managed block), or when the user opts to edit raw Lua
/// (05_GUI_Concept §2). Edits here write the whole file verbatim.
struct LuaEditorTab: View {
    @ObservedObject var model: SettingsModel
    @State private var confirmingAdopt = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            LuaSourceEditor(text: $model.luaSource)
                .onChange(of: model.luaSource) { _, _ in
                    model.isDirty = true
                }
        }
        .padding(16)
        .confirmationDialog(
            "Adopt this config into the visual editor?",
            isPresented: $confirmingAdopt,
            titleVisibility: .visible
        ) {
            Button("Adopt") { model.adoptIntoGui() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Your current gaps, layouts, and rules are "
                    + "imported. Your existing file is kept as a "
                    + "commented backup. Keybindings can't be "
                    + "imported automatically — re-add them in "
                    + "the Keybindings tab."
            )
        }
    }

    @ViewBuilder private var header: some View {
        if model.forcedLuaEditor {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text(
                        "This init.lua contains custom code, so "
                            + "the visual editor is disabled to "
                            + "avoid overwriting it. Edit the Lua "
                            + "directly below."
                    )
                } icon: {
                    Image(systemName: "curlybraces")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                Button("Adopt into the GUI…") {
                    confirmingAdopt = true
                }
            }
        } else {
            HStack {
                Text("Editing init.lua directly.")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Back to visual editor") {
                    model.showLuaEditor = false
                    model.reload()
                }
            }
            .font(.callout)
        }
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
