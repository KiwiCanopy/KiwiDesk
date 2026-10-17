import KiwiDeskCore
import SwiftUI

/// Draft diff change list view with navigation jumps
/// (`SettingsDiffRow`, #678 turn 9).
struct SettingsDiffRowsView: View {
    var rows: [SettingsDiffRow]
    /// The live rows' Keep, where this list offers one (#2368).
    var keep: LiveKeep? = nil
    var jump: (SettingsDiffRow) -> Void
    /// The live section draws this many rows until opened (#2262).
    static let liveCap = 5
    @State private var showsAllLive = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(rows.filter { $0.section == .draft }) { row in
                rowButton(row)
            }
            liveSection
        }
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
                liveRow(row)
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
    private func liveRow(_ row: SettingsDiffRow) -> some View {
        if let keep, !row.keepIDs.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    rowButton(row)
                    LiveKeepButton(row: row, keep: keep)
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
                    keep.keep(row.keepIDs)
                }
                .buttonStyle(.plain)
            }
        } else {
            rowButton(row)
        }
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
