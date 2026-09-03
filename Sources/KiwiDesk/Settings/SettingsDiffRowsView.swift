import KiwiDeskCore
import SwiftUI

/// Draft diff change list view with navigation jumps
/// (`SettingsDiffRow`, #678 turn 9).
struct SettingsDiffRowsView: View {
    var rows: [SettingsDiffRow]
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
