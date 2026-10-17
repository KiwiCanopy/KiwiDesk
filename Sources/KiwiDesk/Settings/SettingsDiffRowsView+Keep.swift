import KiwiDeskCore
import SwiftUI

/// What the pill's live rows may keep into the live profile
/// (#2368): its name for the sentences, every unsaved leaf for
/// Keep All, the keep itself, and the leaves the last keep refused.
@MainActor
struct LiveKeep {
    let profile: String
    let allIDs: [String]
    let refusals: [String: NotKeepable]
    let perform: ([String]) -> LiveKeepOutcome?

    /// Keeps `ids` and speaks the outcome once: a kept row leaves
    /// the list silently and a refusal draws under a row, so the
    /// sentence is VoiceOver's only feedback for either.
    func keep(_ ids: [String]) {
        guard let outcome = perform(ids) else { return }
        _ = DelayedAnnouncement.schedule(sentence(for: outcome))
    }

    private func sentence(for outcome: LiveKeepOutcome) -> String {
        if let reason = outcome.refused.values.first {
            return Self.text(for: reason)
        }
        return outcome.sharedLook
            ? L("diff.live.kept_shared", "Kept in the shared look.")
            : L("diff.live.kept", "Kept in “%1$@”.", profile)
    }

    /// Why the last keep left `row` listed, if it did.
    func refusal(for row: SettingsDiffRow) -> String? {
        row.keepIDs.compactMap { refusals[$0] }.first.map(Self.text)
    }

    private static func text(for reason: NotKeepable) -> String {
        reason == .conflicting
            ? L(
                "diff.live.keep.conflicting",
                "Couldn't keep this — it doesn't fit the saved profile."
            )
            : L("diff.live.keep.not_written", "Couldn't keep this setting.")
    }
}

/// A live row's trailing Keep (#2368): a small text button beside
/// the row's jump, never inside it.
struct LiveKeepButton: View {
    let row: SettingsDiffRow
    let keep: LiveKeep
    /// Runs the keep; the list states where focus goes after.
    let action: () -> Void

    var body: some View {
        Button(L("diff.live.keep", "Keep"), action: action)
            .settingsActionButton()
            .controlSize(.small)
            .help(hint)
            .accessibilityHint(hint)
    }

    private var hint: String {
        L(
            "diff.live.keep.hint",
            "Keeps this live change so it lasts past a restart."
        )
    }
}

/// The live section's Keep All: every unsaved leaf, folded rows
/// and any leaf no row narrates included (#2368).
struct LiveKeepAllButton: View {
    let keep: LiveKeep

    var body: some View {
        Button(L("diff.live.keep_all", "Keep All")) {
            keep.keep(keep.allIDs)
        }
        .settingsActionButton()
        .controlSize(.small)
        .help(hint)
        .accessibilityHint(hint)
    }

    private var hint: String {
        L(
            "diff.live.keep_all.hint",
            "Keeps every live change so it lasts past a restart."
        )
    }
}
