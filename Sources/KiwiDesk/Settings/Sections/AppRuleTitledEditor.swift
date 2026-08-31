import KiwiDeskCore
import SwiftUI

/// Editor for window title matching patterns within an app rule (#68 §3.11).
struct AppRuleTitledEditor: View {
    @ObservedObject var model: SettingsModel
    let app: String
    @Binding var editingTitles: Bool
    @State private var customPattern = ""
    @State private var addingCustom = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !patterns.isEmpty {
                WrapChips(patterns) { pattern in
                    patternChip(pattern)
                }
            }
            HStack(spacing: 8) {
                addWindowMenu
                if addingCustom {
                    TextField(
                        L(
                            "app_rules.title_contains",
                            "Title contains…"
                        ),
                        text: $customPattern
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                    .onSubmit { commitCustom() }
                    Button(L("app_rules.add", "Add")) {
                        commitCustom()
                    }
                    .disabled(customPattern.trimmed.isEmpty)
                    .settingsActionButton()
                }
            }
            AppRuleMatchPreview(
                model: model,
                app: app,
                pending: addingCustom ? customPattern : ""
            )
            Text(titledPatternCaption)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    /// Deduplicated, because the chips are identified by VALUE.
    /// `addPattern` refuses a duplicate, but `floatRules` decodes
    /// straight from JSON and a hand-written config can repeat
    /// one — which under value identity is two `ForEach` children
    /// claiming one id (code review, 2026-08-04). Order is the
    /// config's; only the repeat is dropped.
    private var patterns: [String] {
        var seen: Set<String> = []
        return FloatFacet.patterns(
            model.config.floatRules,
            app: app
        )
        .filter { seen.insert($0).inserted }
    }

    private var titledPatternCaption: String {
        L(
            "app_rules.titled.caption",
            "Windows whose title contains a pattern "
                + "stay floating."
        )
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
    /// titles, plus the free-text escape for windows that
    /// aren't open right now.
    private var addWindowMenu: some View {
        Menu {
            ForEach(openTitles, id: \.self) { title in
                Button(title) { addPattern(title) }
            }
            if !openTitles.isEmpty { Divider() }
            Button(
                L("app_rules.other_specify", "Other (Specify)…")
            ) {
                addingCustom = true
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
    }

    private var openTitles: [String] {
        let covered = patterns
        return Set(
            model.core.state.windows.all
                .filter { $0.appBundleID == app }
                .map(\.title)
        )
        .subtracting(covered)
        .filter { !$0.isEmpty }
        .sorted()
    }

    // MARK: - Mutations (GUI assembles the colon syntax)

    private func addPattern(_ pattern: String) {
        let rule = "\(app):\(pattern)"
        model.config.floatRules.removeAll { $0 == app }
        guard !model.config.floatRules.contains(rule) else {
            return
        }
        model.config.floatRules.append(rule)
        editingTitles = true
    }

    private func removePattern(_ pattern: String) {
        model.config.floatRules.removeAll {
            $0 == "\(app):\(pattern)"
        }
        if patterns.isEmpty { editingTitles = true }
    }

    private func commitCustom() {
        let pattern = customPattern.trimmed
        guard !pattern.isEmpty else { return }
        addPattern(pattern)
        customPattern = ""
        addingCustom = false
    }
}
