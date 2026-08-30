import KiwiDeskCore
import SwiftUI

/// Previews what an app rule matches against open windows as the user types
/// (#123, `FloatRules.matches`). Title patterns are the one part whose effect
/// cannot be read off the rule text alone.
struct AppRuleMatchPreview: View {
    @ObservedObject var model: SettingsModel
    let app: String
    /// Uncommitted pending pattern.
    var pending: String = ""

    var body: some View {
        if windows.isEmpty {
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
                    L(
                        "app_rules.matches.title",
                        "What this rule matches"
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                ForEach(windows, id: \.self) { window in
                    verdictRow(window)
                }
            }
        }
    }

    private func verdictRow(_ window: PreviewWindow) -> some View {
        let verdict = verdict(for: window)
        return HStack(spacing: 6) {
            Image(
                systemName: verdict == .tiles
                    ? "square.grid.2x2" : "macwindow.on.rectangle"
            )
            .font(.caption2)
            .foregroundStyle(
                verdict == .tiles
                    ? SettingsTheme.ink2 : SettingsTheme.accent
            )
            Text(window.title)
                .font(.caption)
                .lineLimit(1)
            Text(label(for: verdict))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Result state for a window under the draft rule.
    enum Verdict: Hashable {
        /// This rule catches it.
        case floatsByRule
        /// Window floats due to system/dialog detection independently of rule.
        case floatsAnyway
        case tiles
    }

    private func label(for verdict: Verdict) -> String {
        switch verdict {
        case .floatsByRule:
            return L("app_rules.matches.floats", "floats")
        case .floatsAnyway:
            return L(
                "app_rules.matches.floats_anyway",
                "floats anyway"
            )
        case .tiles:
            return L("app_rules.matches.tiles", "tiles")
        }
    }

    /// Open window title and engine floating status.
    struct PreviewWindow: Hashable {
        let title: String
        let isFloating: Bool
    }

    /// Open windows deduped by title in stable alphabetical order.
    var windows: [PreviewWindow] {
        var byTitle: [String: Bool] = [:]
        for window in model.core.state.windows.all
        where window.appBundleID == app && !window.title.isEmpty {
            byTitle[window.title] =
                (byTitle[window.title] ?? false) || window.isFloating
        }
        return byTitle.keys.sorted().map {
            PreviewWindow(title: $0, isFloating: byTitle[$0] ?? false)
        }
    }

    /// Resolves rule match first, falling back to engine floating status.
    func verdict(for window: PreviewWindow) -> Verdict {
        var staged = model.config.floatRules
        let typed = pending.trimmed
        if !typed.isEmpty {
            staged.append("\(app):\(typed)")
        }
        if FloatRules(staged)
            .matches(bundleID: app, title: window.title)
        {
            return .floatsByRule
        }
        return window.isFloating ? .floatsAnyway : .tiles
    }
}
