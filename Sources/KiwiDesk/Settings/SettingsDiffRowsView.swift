import KiwiDeskCore
import SwiftUI

/// Draft diff change list view with navigation jumps
/// (`SettingsDiffRow`, #678 turn 9).
struct SettingsDiffRowsView: View {
    var rows: [SettingsDiffRow]
    /// The live rows' Keep, where this list offers one (#2368).
    var keep: LiveKeep? = nil
    /// The draft rows' ↺, where this list offers one (#792).
    var revert: DiffRowRevert? = nil
    var jump: (SettingsDiffRow) -> Void
    /// The live section draws this many rows until opened (#2262).
    static let liveCap = 5
    @State private var showsAllLive = false
    /// The live row whose Keep holds focus after a keep (#2368).
    @FocusState private var focusedKeep: String?
    /// The draft row whose ↺ holds focus, which also draws it (#792).
    @FocusState private var focusedRevert: String?
    /// The draft row under the pointer, whose ↺ the panel draws.
    @State private var hoveredRow: String?
    /// Rows a keyboard ↺ may hand focus to, nearest first.
    @State private var focusAfterRevert: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            let drafts = rows.filter { $0.section == .draft }
            ForEach(drafts) { row in
                draftRow(row, among: drafts)
            }
            liveSection
        }
        .onChange(of: rows.map(\.id)) { _, _ in settleRevertFocus() }
    }

    /// A draft row, with its ↺ where it has a way back (#792).
    @ViewBuilder
    private func draftRow(
        _ row: SettingsDiffRow,
        among shown: [SettingsDiffRow]
    ) -> some View {
        if let revert, revert.can(row) {
            HStack(spacing: 6) {
                rowButton(row)
                RowRevertButton(row: row) {
                    revertRow(row, among: shown, with: revert)
                }
                .focused($focusedRevert, equals: row.id)
                .opacity(showsRevert(row, revert) ? 1 : 0)
            }
            .onHover { inside in
                if inside {
                    hoveredRow = row.id
                } else if hoveredRow == row.id {
                    hoveredRow = nil
                }
            }
            .rowActions {
                // A menu row: the style is the menu's.
                Button(DiffRowRevert.actionName) {
                    revertRow(row, among: shown, with: revert)
                }
                .buttonStyle(.plain)
            }
        } else {
            rowButton(row)
        }
    }

    private func showsRevert(
        _ row: SettingsDiffRow,
        _ revert: DiffRowRevert
    ) -> Bool {
        revert.alwaysVisible || hoveredRow == row.id
            || focusedRevert == row.id
    }

    /// Reverts one row. Under a keyboard press focus moves to the
    /// nearest row's ↺ still drawn after the revert, which may take
    /// a neighbour with it: the candidates are read before the row
    /// goes (#816), the survivor once the list has redrawn.
    private func revertRow(
        _ row: SettingsDiffRow,
        among shown: [SettingsDiffRow],
        with revert: DiffRowRevert
    ) {
        let ids = shown.map(\.id)
        let at = ids.firstIndex(of: row.id) ?? ids.count
        let candidates =
            Array(ids.suffix(from: min(at + 1, ids.count)))
            + ids.prefix(at).reversed()
        revert.perform(row)
        if SettingsInputSource.movesFocus { focusAfterRevert = candidates }
    }

    /// Focuses the first candidate whose ↺ the redrawn list draws.
    private func settleRevertFocus() {
        guard !focusAfterRevert.isEmpty, let revert else { return }
        let next = focusAfterRevert.compactMap { id in
            rows.first { $0.id == id && $0.section == .draft }
        }.first(where: revert.can)
        focusAfterRevert = []
        if let next { focusedRevert = next.id }
    }

    /// Stored settings changed live and not saved, under their own
    /// heading so they never read as the draft's edits (#2262).
    @ViewBuilder
    private var liveSection: some View {
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

    /// A live row, with its Keep and any refusal under it.
    @ViewBuilder
    private func liveRow(
        _ row: SettingsDiffRow,
        among shown: [SettingsDiffRow]
    ) -> some View {
        if let keep, !row.keepIDs.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    rowButton(row)
                    LiveKeepButton(row: row, keep: keep) {
                        keepRow(row, among: shown, with: keep)
                    }
                    .focused($focusedKeep, equals: row.id)
                }
                if let refusal = keep.refusal(for: row) {
                    Label(refusal, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(SettingsTheme.ink3)
                }
            }
            .rowActions {
                // A menu row: the style is the menu's.
                Button(L("diff.live.keep", "Keep")) {
                    keepRow(row, among: shown, with: keep)
                }
                .buttonStyle(.plain)
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

    private func rowButton(_ row: SettingsDiffRow) -> some View {
        Button {
            jump(row)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(row.label)
                    .foregroundStyle(SettingsTheme.ink)
                    .lineLimit(1)
                Spacer(minLength: 12)
                valueReadout(row)
            }
            .font(.callout)
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .rowHoverHighlight()
        .padding(.horizontal, -6)
        .accessibilityElement(children: .combine)
    }

    /// Renders old -> new value change readout.
    @ViewBuilder
    private func valueReadout(
        _ row: SettingsDiffRow
    ) -> some View {
        if let note = row.changeNote {
            Text(note)
                .foregroundStyle(SettingsTheme.ink3)
        } else {
            HStack(spacing: 5) {
                Text(row.oldValue ?? unsetMark)
                    .foregroundStyle(SettingsTheme.ink3)
                Text(verbatim: "→")
                    .foregroundStyle(SettingsTheme.ink3)
                Text(row.newValue ?? unsetMark)
                    .fontWeight(.semibold)
                    .foregroundStyle(SettingsTheme.groupHeading)
            }
            .lineLimit(1)
        }
    }

    private var unsetMark: String {
        L("diff.value.unset", "—")
    }
}

/// Navigation anchor resolver for settings diff rows
/// (`SettingsAnchorPairingTests`).
@MainActor
enum SettingsDiffJump {
    /// Resolves target anchor for jumping to changed setting control.
    static func anchor(
        for row: SettingsDiffRow
    ) -> SettingsAnchor? {
        guard let area = row.key.placement.area else {
            return nil
        }
        var anchor = SettingsAnchor(
            destination: SettingsDestination(area: area)
        )
        if !row.jumpsToAreaRoot,
            case .key(let labelKey) = row.key.text.label
        {
            anchor.anchor = labelKey
        }
        return anchor
    }
}
