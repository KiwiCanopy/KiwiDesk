import KiwiDeskCore
import SwiftUI

/// The settings both Macs changed, picked at Save (#2450): one row
/// per conflict, each starting unpicked, and Save dimmed beside a
/// warning band until every row is picked. Its commit runs through
/// the host's closures and it takes no model — a ruled exception to
/// a read-only sheet, like Compare and Copy's
/// (`SheetPresentationSeamTests`).
struct SyncReviewSheet: View {
    let review: SyncReview
    /// The footer's own Save label, since the pick runs that Save.
    let saveLabel: String
    let onSave: ([String: SyncChoice]) -> Void
    let onCancel: () -> Void

    @State private var picks: [String: SyncChoice] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            rows
            if !allPicked { warning }
            footer
        }
        .padding(20)
        .frame(width: 520)
        .background(SettingsTheme.card)
    }

    /// Whether every row has a side.
    var allPicked: Bool {
        Self.allPicked(review, picks)
    }

    static func allPicked(
        _ review: SyncReview,
        _ picks: [String: SyncChoice]
    ) -> Bool {
        review.rows.allSatisfy { picks[$0.id] != nil }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(SyncText.reviewTitle(mac: review.mac))
                .font(.title3)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            if review.taken > 0 { note(SyncText.taken(review.taken)) }
            if review.yourOthers > 0 {
                note(SyncText.yourOthers(review.yourOthers))
            }
        }
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(review.rows) { row in
                if row.id != review.rows.first?.id { Divider() }
                rowView(row)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(SettingsTheme.sunken)
        )
    }

    private func rowView(_ row: SyncReview.Row) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.label)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)
                Text(SyncText.values(yours: row.yours, theirs: row.theirs))
                    .font(.callout)
                    .foregroundStyle(SettingsTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            SegmentedPicker(
                spokenLabel: row.label,
                spokenValue: SyncText.spokenPick(picks[row.id], row: row),
                selection: pick(row),
                options: [
                    (SyncText.yours, SyncChoice?.some(.yours)),
                    (SyncText.theirs, SyncChoice?.some(.theirs)),
                ]
            )
            .fixedSize()
        }
        .padding(10)
    }

    private func pick(_ row: SyncReview.Row) -> Binding<SyncChoice?> {
        Binding(
            get: { picks[row.id] },
            set: { picks[row.id] = $0 }
        )
    }

    /// Glyph and words, never hue alone, in the warning colours.
    private var warning: some View {
        Label(SyncText.pickEach, systemImage: "exclamationmark.triangle")
            .font(.callout.weight(.medium))
            .foregroundStyle(SettingsTheme.warningInk)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(SettingsTheme.warningSurface)
            )
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(SettingsTheme.ink2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(SyncText.cancel, action: onCancel)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
                .settingsActionButton()
            Button(saveLabel) { onSave(picks) }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .kiwiProminentButton()
                .disabled(!allPicked)
                .accessibilityHint(allPicked ? "" : SyncText.pickEach)
        }
    }
}
