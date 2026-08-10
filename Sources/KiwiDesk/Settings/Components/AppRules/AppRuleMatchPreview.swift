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
/// **The verdict comes from the engine, never from a rule
/// re-derived here** (gui.md: a preview that claims to show
/// engine behavior asks the engine). Two engines answer, and
/// using only one is how the first cut of this view lied:
/// `FloatRules.matches` decides whether the RULE catches a
/// window — lowercasing bundle ids, comparing title fragments
/// case-SENSITIVELY — while `WindowModel.isFloating` carries the
/// settled answer, which includes the dialogs and panels
/// `FloatDetection` floats with no rule at all. Asking only the
/// first labelled Finder's "Get Info" **tiles** while the
/// running app floats it, contradicting the user guide on the
/// same screen.
///
/// So a window floating for a reason other than this rule says
/// so, rather than being folded into the rule's verdict: the
/// reader is deciding whether their rule is right, and "it
/// floats anyway" is the answer that stops them writing a rule
/// they do not need.
///
/// One limit, stated rather than hidden: `isFloating` is the
/// LIVE session's verdict and the rules here are a DRAFT. Delete
/// a saved rule without saving and its windows still read
/// "floats anyway", because in the running app they still do.
/// That is the honest reading of two different clocks, and the
/// alternative — recomputing `FloatDetection` over staged
/// config — needs the AX role and layer of each window, which
/// is the live-apply coupling #123 rejects.
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

    /// What happens to a window, in the three states that are
    /// actually distinguishable — collapsing the third into
    /// "floats" is what made the first cut disagree with the app.
    enum Verdict: Hashable {
        /// This rule catches it.
        case floatsByRule
        /// It floats regardless — a dialog, a panel, an
        /// accessory app's window — so the rule is not what is
        /// doing it, and removing the rule will not tile it.
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

    /// One open window as the preview needs it: the title the
    /// rule matches on, and the engine's settled float verdict.
    struct PreviewWindow: Hashable {
        let title: String
        let isFloating: Bool
    }

    /// The app's open windows, deduped by title and in a stable
    /// order so the list does not reshuffle under the reader
    /// between keystrokes. A title open twice keeps the floating
    /// reading if either copy floats — the reader is asking
    /// about the title, which is all a rule can name.
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

    /// The verdict for one window: the rule first, then the
    /// engine's settled answer for everything the rule does not
    /// claim.
    ///
    /// Internal rather than private so the guard can assert the
    /// PREVIEW's verdict rather than only scanning for the call:
    /// a scan is one spelling deep, and guard-prover slipped a
    /// plausible "fast path while typing" (`title.range(of:)`)
    /// past it — which disagrees with the engine on exactly the
    /// pending pattern the user is watching.
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
