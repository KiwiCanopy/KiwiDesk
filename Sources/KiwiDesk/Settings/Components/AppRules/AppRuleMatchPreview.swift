import KiwiDeskCore
import SwiftUI

/// "What this rule matches" (turn 14a): the app's currently
/// open windows, each labelled with what the rule being edited
/// would do to it — **as you type**, so a rule is verified
/// before it is saved rather than after it misfires.
///
/// A title pattern is the one part of an app rule whose effect
/// you cannot read off the rule itself. "Windows titled Info"
/// looks obviously right until it also catches "Information",
/// or misses "Get Info" because the match is case-sensitive.
/// The rule's own text can never answer that; the user's actual
/// window titles can.
///
/// **The verdict comes from the engine's own matcher**
/// (`FloatRules.matches`), never from a `contains` written here.
/// That matcher lowercases bundle ids and compares title
/// fragments case-SENSITIVELY, which is exactly the pair of
/// details a re-implementation gets wrong — and a preview that
/// disagrees with the engine is worse than no preview, because
/// it is trusted.
///
/// Live window state, not AX: `state.windows` is the snapshot
/// the app already keeps, and the same one this row's
/// open-window picker reads. Nothing here reaches the
/// accessibility layer, so typing a character costs a filter
/// over an array the GUI already holds.
struct AppRuleMatchPreview: View {
    @ObservedObject var model: SettingsModel
    let app: String
    /// The pattern being typed but not yet committed, so the
    /// list answers the question while it is still being asked.
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
                ForEach(windows, id: \.self) { title in
                    verdictRow(title)
                }
            }
        }
    }

    private func verdictRow(_ title: String) -> some View {
        HStack(spacing: 6) {
            Image(
                systemName: floats(title)
                    ? "macwindow.on.rectangle" : "square.grid.2x2"
            )
            .font(.caption2)
            .foregroundStyle(
                floats(title) ? Color.accentColor : .secondary
            )
            Text(title)
                .font(.caption)
                .lineLimit(1)
            Text(
                floats(title)
                    ? L("app_rules.matches.floats", "floats")
                    : L("app_rules.matches.tiles", "tiles")
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    /// The app's open window titles, in a stable order so the
    /// list does not reshuffle under the reader between
    /// keystrokes.
    private var windows: [String] {
        Set(
            model.core.state.windows.all
                .filter { $0.appBundleID == app }
                .map(\.title)
        )
        .filter { !$0.isEmpty }
        .sorted()
    }

    /// The engine's verdict for one title, over the staged rules
    /// plus whatever is half-typed.
    private func floats(_ title: String) -> Bool {
        var staged = model.config.floatRules
        let typed = pending.trimmed
        if !typed.isEmpty {
            staged.append("\(app):\(typed)")
        }
        return FloatRules(staged)
            .matches(bundleID: app, title: title)
    }
}
