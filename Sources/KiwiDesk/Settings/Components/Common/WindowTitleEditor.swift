import KiwiDeskCore
import SwiftUI

/// Editor for the title patterns that pick some of an app's
/// windows (#68 §3.11, #2103 ruling 43): a chip per pattern, a menu
/// of the app's open titles, a free-text escape, the caller's
/// preview of what the patterns match and its caption. A pattern
/// matches as `WindowTitleMatch` reads it; where the patterns are
/// stored is the caller's.
struct WindowTitleEditor<Preview: View>: View {
    @ObservedObject var model: SettingsModel
    @Binding var patterns: [String]
    /// The app's bundle id, whose open windows the menu offers.
    let app: String
    let caption: String
    /// What the patterns match, handed the pattern being typed.
    @ViewBuilder let preview: (String) -> Preview
    @State private var draft = TitlePatternDraft()
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !shown.isEmpty {
                WrapChips(shown) { pattern in
                    patternChip(pattern)
                }
            }
            HStack(spacing: 8) {
                addWindowMenu
                if draft.isOpen {
                    patternField
                    Button(L("app_rules.add", "Add")) {
                        commitDraft()
                    }
                    .disabled(draft.text.trimmed.isEmpty)
                    .settingsActionButton()
                }
            }
            preview(draft.isOpen ? draft.text : "")
            Text(caption)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    /// The pending pattern (#3340): Return adds, Escape drops.
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
        .focused($fieldFocused)
        .onSubmit { commitDraft() }
        .onExitCommand { draft.cancel() }
    }

    /// Deduplicated, because the chips are identified by VALUE.
    /// `addPattern` refuses a duplicate, but a store decoded
    /// straight from JSON can repeat one — which under value
    /// identity is two `ForEach` children claiming one id (code
    /// review, 2026-08-04). Order is the store's; only the repeat
    /// is dropped.
    private var shown: [String] {
        var seen: Set<String> = []
        return patterns.filter { seen.insert($0).inserted }
    }

    private func patternChip(_ pattern: String) -> some View {
        HStack(spacing: 4) {
            Text(pattern)
                .font(.caption)
            Button {
                removePattern(pattern)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 9))
            }
            .buttonStyle(.borderless)
            .iconButtonAffordance(
                L(
                    "app_rules.remove_pattern",
                    "Remove title pattern"
                )
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(.tint.opacity(0.15)))
        .overlay(
            Capsule().strokeBorder(.tint.opacity(0.4))
        )
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
        let covered = shown
        return Set(
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

    // MARK: - Mutations

    private func addPattern(_ pattern: String) {
        guard !patterns.contains(pattern) else { return }
        patterns.append(pattern)
    }

    private func removePattern(_ pattern: String) {
        patterns.removeAll { $0 == pattern }
    }

    /// A picked title opens the field on it, selected, so Return
    /// keeps it whole and an arrow key trims it (#3340). The field
    /// editor selects a turn later, once the field holds the text.
    private func startDraft(with title: String = "") {
        draft.start(with: title)
        fieldFocused = true
        DispatchQueue.main.async {
            (NSApp.keyWindow?.firstResponder as? NSText)?.selectAll(nil)
        }
    }

    private func commitDraft() {
        guard let pattern = draft.commit() else { return }
        addPattern(pattern)
    }
}
