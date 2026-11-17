import KiwiDeskCore
import SwiftUI

/// What a title popover opens with (#3373): one per presentation,
/// so the popover's own text is fresh each time (#843).
struct TitlePatternRequest: Identifiable, Equatable {
    let id = UUID()
    /// The text the field opens holding: a titled row's fragment
    /// for Change Title…, empty otherwise.
    let seed: String
}

/// Composes one title pattern in a popover (#3340, #3341, #3373):
/// the app's open titles listed, the "Title contains…" field below
/// them, the refusal caption, the caller's live check of what the
/// typed pattern would match (#123), Cancel and Add. A picked title fills
/// the field selected, so Return keeps it whole and an arrow key
/// trims it. Shared by a Space row's scope cell and the Float rows'
/// chip editor (`WindowTitleEditor`).
struct TitlePatternPopover<Preview: View>: View {
    @ObservedObject var model: SettingsModel
    /// The app's rule key, whose open windows the list offers.
    let app: String
    /// Patterns the list leaves out: they have a row or a chip.
    let covered: [String]
    let seed: String
    /// Why the typed pattern cannot be added; nil where it can.
    var refusal: (String) -> String? = { _ in nil }
    /// What the patterns would match, handed the one being typed.
    @ViewBuilder let preview: (String) -> Preview
    let onCommit: (String) -> Void
    let onCancel: () -> Void
    @State private var draft = TitlePatternDraft()
    @FocusState private var fieldFocused: Bool

    private static var width: CGFloat { 280 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !openTitles.isEmpty { titleList }
            patternField
            if let reason = refusal(draft.text.trimmed) {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            preview(draft.text)
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button(L("app_rules.title_popover.cancel", "Cancel")) {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                .settingsActionButton()
                Button(L("app_rules.add", "Add"), action: commitDraft)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canAdd)
                    .kiwiProminentButton()
            }
        }
        .frame(width: Self.width, alignment: .leading)
        .padding(12)
        .onAppear { draft.start(with: seed) }
    }

    /// The open titles, a click filling the field (#3373).
    private var titleList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(
                L("app_rules.title_popover.open_windows", "Open windows")
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(SettingsTheme.ink2)
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(openTitles, id: \.self) { title in
                        Button {
                            draft.start(with: title)
                        } label: {
                            Text(title)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(SettingsTheme.ink)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .rowHoverHighlight()
                    }
                }
            }
            .frame(maxHeight: 118)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var canAdd: Bool {
        let typed = draft.text.trimmed
        return !typed.isEmpty && refusal(typed) == nil
    }

    /// Return or Add adds and Escape cancels (#3373): the popover's
    /// own confirm, never a blur, which an outside click that
    /// dismisses it would read as Add. Focus and the selection wait
    /// for the field to mount, then select only its own text.
    private var patternField: some View {
        TextField(
            L("app_rules.title_contains", "Title contains…"),
            text: $draft.text
        )
        .textFieldStyle(.roundedBorder)
        .focused($fieldFocused)
        .onSubmit(commitDraft)
        .onAppear(perform: focusPick)
        .onChange(of: draft.picks) { focusPick() }
    }

    private var openTitles: [String] {
        Set(
            AppRuleWindows.of(app, in: model.core).map(\.title)
        )
        .subtracting(covered)
        .filter { !$0.isEmpty }
        .sorted()
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

    private func commitDraft() {
        guard canAdd, let pattern = draft.commit() else { return }
        onCommit(pattern)
    }
}
