import KiwiDeskCore
import SwiftUI

/// The "Live, not saved" section of the diff list (#2262): each
/// row's Keep (#2368) and its ↺, which puts the live change back to
/// the stored value (#2411).
extension SettingsDiffRowsView {
    /// Stored settings changed live and not saved, under their own
    /// heading so they never read as the draft's edits (#2262).
    @ViewBuilder
    var liveSection: some View {
        let live = rows.filter { $0.section == .live }
        if !live.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                Text(L("diff.live.heading", "Live, not saved"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SettingsTheme.ink3)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                // One row's Keep is the whole list's (#2368).
                if let keep, live.count > 1 {
                    LiveKeepAllButton(rows: live, keep: keep)
                }
            }
            .padding(.top, live.count == rows.count ? 0 : 8)
            let shown =
                showsAllLive || live.count <= Self.liveCap + 1
                ? live : Array(live.prefix(Self.liveCap))
            ForEach(shown) { row in
                liveRow(row, among: shown)
            }
            if shown.count < live.count {
                moreButton(hidden: live.count - shown.count)
            }
        }
    }

    /// Opens the rest of the live section in place.
    private func moreButton(hidden: Int) -> some View {
        Button {
            showsAllLive = true
        } label: {
            Text(L("diff.live.more", "More: %1$d", hidden))
                .font(.callout)
                .foregroundStyle(SettingsTheme.ink3)
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rowHoverHighlight()
        .padding(.horizontal, -6)
    }

    /// A live row, with its Keep, its ↺ and any refusal under it.
    @ViewBuilder
    private func liveRow(
        _ row: SettingsDiffRow,
        among shown: [SettingsDiffRow]
    ) -> some View {
        if let keep, !row.keepIDs.isEmpty {
            let back = revert.flatMap { $0.can(row) ? $0 : nil }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    rowButton(row)
                    LiveKeepButton(row: row, keep: keep) {
                        keepRow(row, among: shown, with: keep)
                    }
                    .focused($focusedKeep, equals: row.id)
                    if let back {
                        RowRevertButton(row: row, group: false) {
                            revertLiveRow(row, among: shown, with: back)
                        }
                        .focused($focusedRevert, equals: row.id)
                    }
                }
                if let refusal = keep.refusal(for: row) {
                    Label(refusal, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(SettingsTheme.ink3)
                }
            }
            .rowActions {
                // Menu rows: the style is the menu's.
                Button(L("diff.live.keep", "Keep")) {
                    keepRow(row, among: shown, with: keep)
                }
                .buttonStyle(.plain)
                if let back {
                    Button(DiffRowRevert.actionName) {
                        revertLiveRow(row, among: shown, with: back)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            rowButton(row)
        }
    }

    /// Keeps one row; where the row leaves under a keyboard press,
    /// focus moves to the neighbouring row's Keep, read before the
    /// row goes (#816). The last row's leaving empties the popover,
    /// whose close hands focus back to the pill.
    private func keepRow(
        _ row: SettingsDiffRow,
        among shown: [SettingsDiffRow],
        with keep: LiveKeep
    ) {
        let next = DeletionFocus.neighbour(after: row, in: shown)
        guard keep.keep(row.keepIDs), SettingsInputSource.movesFocus,
            let next
        else { return }
        focusedKeep = next.id
    }

    /// Reverts one live row; under a keyboard press focus moves to
    /// the neighbouring row's ↺, read before the row goes (#816).
    private func revertLiveRow(
        _ row: SettingsDiffRow,
        among shown: [SettingsDiffRow],
        with revert: DiffRowRevert
    ) {
        let next = DeletionFocus.neighbour(after: row, in: shown)
        revert.perform(row)
        guard SettingsInputSource.movesFocus, let next else { return }
        focusedRevert = next.id
    }
}
