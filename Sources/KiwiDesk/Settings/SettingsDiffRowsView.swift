import KiwiDeskCore
import SwiftUI

/// The one renderer of draft-diff rows (#678 turn 9, digest
/// §1.1): the detail panel's "CHANGED IN THIS DRAFT" list and
/// Home's unsaved-changes popover both mount THIS view, so the
/// draft has one row vocabulary and the two surfaces cannot
/// drift. Each row is a jump: clicking it opens the owning
/// area and reveals the control that changed (the prototype's
/// "each row is clickable" note), through the same anchor
/// machinery search uses.
struct SettingsDiffRowsView: View {
    var rows: [SettingsDiffRow]
    /// The mount decides what surrounds the jump (the popover
    /// dismisses itself first; the panel navigates in place).
    var jump: (SettingsDiffRow) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(rows) { row in
                rowButton(row)
            }
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
        // The search rows' hover treatment (owner 2026-08-10):
        // a jump row is a full-row button whose list context is
        // its rest affordance, and without the wash there is
        // nothing saying which row the pointer is on. The
        // shared `Color.primary` chip is right here — both
        // mounts (popover, panel) sit on mode-varying surfaces.
        .rowHoverHighlight()
        .padding(.horizontal, -6)
        .accessibilityElement(children: .combine)
    }

    /// The right-hand half. The old → new pair is symbolic
    /// notation (two VALUES around an arrow), not a sentence —
    /// no locale reorders a before/after readout, which is why
    /// this is a stack and not a positional frame; the labels
    /// and notes around it stay localized frames as usual.
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
                // The green-emphasis text token, not `accent`
                // (a full-strength value would read clickable)
                // and not `accentInk` (that is dark ink FOR
                // accent fills) — the prototype draws the new
                // value in exactly this deep green.
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

/// The jump every mount shares: the census key's area opens and
/// the row's own control flashes. Pure pairing — the label key
/// IS the anchor id (`SettingsControl.id` is the `L()` key),
/// which `SettingsAnchorPairingTests` holds for cataloged rows.
@MainActor
enum SettingsDiffJump {
    /// The anchor for a row, or nil when the key has no
    /// Settings surface (a Lua-only override) — the jump then
    /// opens the area alone.
    static func anchor(
        for row: SettingsDiffRow
    ) -> SettingsAnchor? {
        guard let area = row.key.placement.area else {
            return nil
        }
        var anchor = SettingsAnchor(
            destination: SettingsDestination(area: area)
        )
        if case .key(let labelKey) = row.key.text.label {
            anchor.anchor = labelKey
        }
        return anchor
    }
}
