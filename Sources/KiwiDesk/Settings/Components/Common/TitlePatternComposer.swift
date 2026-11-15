import KiwiDeskCore
import SwiftUI

/// Composes one title pattern (#3340, #3341): a menu of the app's
/// open titles, each opened in the "Title contains…" field to trim,
/// a free-text escape, and Add. Shared by the Float rows' chip
/// editor (`WindowTitleEditor`) and a titled Space row, which
/// mounts it in its scope cell.
struct TitlePatternComposer: View {
    @ObservedObject var model: SettingsModel
    @Binding var draft: TitlePatternDraft
    /// The app's rule key, whose open windows the menu offers.
    let app: String
    /// Patterns the menu leaves out: they are stored already.
    let covered: [String]
    /// Why the typed pattern cannot be added; nil where it can.
    var refusal: (String) -> String? = { _ in nil }
    let onCommit: (String) -> Void
    /// Escape in the field, after the draft closed.
    var onCancel: () -> Void = {}
    @FocusState private var fieldFocused: Bool
    @FocusState private var menuFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                addWindowMenu
                    .focused($menuFocused)
                if draft.isOpen {
                    patternField
                    Button(L("app_rules.add", "Add")) {
                        commitDraft()
                    }
                    .disabled(!canAdd)
                    .settingsActionButton()
                }
            }
            if draft.isOpen, let reason = refusal(draft.text.trimmed) {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink2)
            }
        }
    }

    private var canAdd: Bool {
        let typed = draft.text.trimmed
        return !typed.isEmpty && refusal(typed) == nil
    }

    /// The pending pattern (#3340): Return, a blur or a Save adds
    /// it; Escape drops it. Focus and the selection wait for the
    /// field to mount, then select only its own text.
    private var patternField: some View {
        TextField(
            L(
                "app_rules.title_contains",
                "Title contains…"
            ),
            text: $draft.text
        )
        .textFieldStyle(.roundedBorder)
        .frame(maxWidth: 200)
        .commitsOnSave($fieldFocused) { commitDraft() }
        .onExitCommand {
            draft.cancel()
            menuFocused = true
            onCancel()
        }
        .onAppear(perform: focusPick)
        .onChange(of: draft.picks) { focusPick() }
    }

    /// Lists the app's currently open, not-yet-covered window
    /// titles, each opened in the pattern field to trim, plus the
    /// free-text escape for windows that aren't open right now.
    private var addWindowMenu: some View {
        Menu {
            ForEach(openTitles, id: \.self) { title in
                Button(title) { startDraft(with: title) }
            }
            if !openTitles.isEmpty { Divider() }
            Button(
                L("app_rules.other_specify", "Other (Specify)…")
            ) {
                startDraft()
            }
        } label: {
            Label(
                L("app_rules.add_window", "Add Window"),
                systemImage: "plus"
            )
            .font(.caption)
        }
        .menuStyle(.borderlessButton)
        .neutralMenuLabel()
        .fixedSize()
        .menuTriggerHover()
    }

    private var openTitles: [String] {
        Set(
            model.core.state.windows.all
                // A lens stores its members lowercased (#2103 ruling
                // 31); a bundle id compares without case.
                .filter {
                    $0.appBundleID?.lowercased() == app.lowercased()
                }
                .map(\.title)
        )
        .subtracting(covered)
        .filter { !$0.isEmpty }
        .sorted()
    }

    /// A picked title opens the field on it, selected, so Return
    /// keeps it whole and an arrow key trims it (#3340).
    private func startDraft(with title: String = "") {
        draft.start(with: title)
    }

    /// Focus lands a turn after the field mounts, and the field
    /// editor selects a turn after that — only while it holds the
    /// picked text, never another field's.
    private func focusPick() {
        DispatchQueue.main.async {
            fieldFocused = true
            DispatchQueue.main.async {
                guard
                    let editor = NSApp.keyWindow?.firstResponder
                        as? NSText,
                    editor.string == draft.text
                else { return }
                editor.selectAll(nil)
            }
        }
    }

    /// Adds the pending pattern. Focus returns to the add menu only
    /// from the field itself, never from a blur to another control.
    private func commitDraft() {
        guard canAdd else { return }
        let fromField = fieldFocused
        guard let pattern = draft.commit() else { return }
        onCommit(pattern)
        if fromField { menuFocused = true }
    }
}
