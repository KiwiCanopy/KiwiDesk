import KiwiDeskCore
import SwiftUI

/// What a titled Space rule being composed would do to the app's
/// open windows (#3341), drawn in the title popover (#3373): the
/// draft staged into the engine's own resolution —
/// `TitledSpaceRules`, then the bare rule — never a `contains` of
/// its own (`docs/design-decisions.md` ▸ App rules).
struct SpaceRuleMatchPreview: View {
    @ObservedObject var model: SettingsModel
    /// The row composing, before its edit.
    let row: SpaceRuleRow
    /// The Space the composed rule opens windows in.
    let space: SpaceID?
    /// The pattern being typed.
    let pending: String

    var body: some View {
        if titles.isEmpty {
            Text(
                L(
                    "app_rules.matches.none_open",
                    "No windows of this app are open right now, "
                        + "so there is nothing to check against."
                )
            )
            .font(.caption)
            .foregroundStyle(.tertiary)
        } else {
            VStack(alignment: .leading, spacing: 3) {
                Text(
                    L("app_rules.matches.title", "What this rule matches")
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                ForEach(titles, id: \.self) { title in
                    verdictRow(title)
                }
            }
        }
    }

    /// A window's verdict under the staged rules.
    enum Verdict: Equatable {
        case opensIn(SpaceID)
        case otherRule(SpaceID)
        case noRule

        /// The composed rule's own catch, the one verdict the
        /// accent marks; the words carry every verdict.
        var isOwn: Bool {
            if case .opensIn = self { return true }
            return false
        }
    }

    private func verdictRow(_ title: String) -> some View {
        let verdict = verdict(for: title)
        return HStack(spacing: 6) {
            Image(systemName: Self.symbol(verdict))
                .font(.caption2)
                .foregroundStyle(
                    verdict.isOwn ? SettingsTheme.accent : SettingsTheme.ink2
                )
            Text(title)
                .font(.caption)
                .lineLimit(1)
            Text(Self.label(verdict))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    static func symbol(_ verdict: Verdict) -> String {
        switch verdict {
        case .opensIn: "checkmark.circle"
        case .otherRule: "arrow.turn.down.right"
        case .noRule: "minus.circle"
        }
    }

    static func label(_ verdict: Verdict) -> String {
        switch verdict {
        case .opensIn(let space):
            L("app_rules.matches.opens_in", "opens in Space %1$@", space.raw)
        case .otherRule(let space):
            L(
                "app_rules.matches.opens_in.other",
                "opens in Space %1$@ by another rule",
                space.raw
            )
        case .noRule:
            L("app_rules.matches.no_rule", "no rule")
        }
    }

    /// The app's open window titles, deduplicated and sorted.
    var titles: [String] {
        Set(
            AppRuleWindows.of(row.app, in: model.core)
                .map(\.title)
                .filter { !$0.isEmpty }
        ).sorted()
    }

    /// The engine's answer for `title` with the draft staged: the
    /// row's rule replaced by the typed one. The row's own rule is
    /// out while the field is empty too, and a fragment another row
    /// holds stages nothing, since Add refuses it.
    func verdict(for title: String) -> Verdict {
        var config = model.config
        SpaceRuleEdit.drop(row, from: &config)
        let typed = pending.trimmed
        let staged = SpaceRuleRow(app: row.app, fragment: typed)
        var own: String?
        if !typed.isEmpty, let space,
            config.titledAppRules[staged.key] == nil
        {
            config.titledAppRules[staged.key] = space
            own = staged.key
        }
        let pick = TitledSpaceRules(config.titledAppRules).pick(
            app: row.app,
            title: title,
            bare: config.appRules
        )
        switch pick {
        case .titled(let rule) where rule.key == own:
            return .opensIn(rule.space)
        case .some(let pick):
            return .otherRule(pick.space)
        case nil:
            return .noRule
        }
    }
}
