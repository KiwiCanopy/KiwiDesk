import KiwiDeskCore
import SwiftUI

/// What the pill's live rows may keep into the live profile
/// (#2368): its name for the hints, the keep itself, and the
/// leaves the last keep refused.
@MainActor
struct LiveKeep {
    let profile: String
    let refusals: [String: NotKeepable]
    /// Keeps the leaves; answers whether every one was kept.
    let perform: ([String]) -> Bool

    /// Keeps `ids` and speaks the outcome once: a kept row
    /// leaves the list silently, so the sentence is the feedback.
    func keep(_ ids: [String]) {
        guard perform(ids) else { return }
        _ = DelayedAnnouncement.schedule(
            L("diff.live.kept", "Kept in “%1$@”.", profile)
        )
    }

    /// Why the last keep left `row` listed, if it did.
    func refusal(for row: SettingsDiffRow) -> String? {
        let reasons = row.keepIDs.compactMap { refusals[$0] }
        guard let reason = reasons.first else { return nil }
        return reason == .conflicting
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

    var body: some View {
        Button(L("diff.live.keep", "Keep")) {
            keep.keep(row.keepIDs)
        }
        .settingsActionButton()
        .controlSize(.small)
        .help(hint)
        .accessibilityHint(hint)
    }

    private var hint: String {
        L(
            "diff.live.keep.hint",
            "Keeps this setting in “%1$@”.",
            keep.profile
        )
    }
}

/// The live section's Keep All, for every live row listed, folded
/// rows included (#2368).
struct LiveKeepAllButton: View {
    let rows: [SettingsDiffRow]
    let keep: LiveKeep

    var body: some View {
        Button(L("diff.live.keep_all", "Keep All")) {
            keep.keep(Array(Set(rows.flatMap(\.keepIDs))).sorted())
        }
        .settingsActionButton()
        .controlSize(.small)
        .help(hint)
        .accessibilityHint(hint)
    }

    private var hint: String {
        L(
            "diff.live.keep_all.hint",
            "Keeps every live change in “%1$@”.",
            keep.profile
        )
    }
}
