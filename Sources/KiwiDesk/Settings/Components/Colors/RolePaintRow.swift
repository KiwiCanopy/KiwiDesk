import KiwiDeskCore
import SwiftUI

/// A role group's colour (#1857): one well over the ticked rows,
/// a "mixed" readout while they differ — the `?` answering it is
/// on the group's title (#1383's shape) — and, greyed while it has
/// nothing to write, the reason beside it rather than in a hover.
struct RolePaintRow: View {
    let role: ColorRole
    let paint: RolePaint
    /// The well's value: the first target's colour, writing every
    /// target (`RolePaint.painted`).
    let hex: Binding<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                HexColorField(
                    label: L("colors.ticked_rows", "Ticked rows"),
                    a11yLabel: L(
                        "colors.ticked_rows.a11y",
                        "Color for ticked rows in %1$@",
                        role.control.text
                    ),
                    hex: hex
                )
                .help(Self.help)
                if paint.mixed {
                    Text(Self.mixedWord)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .modifier(
                GreyOut(active: paint.idle != nil, help: idleReason)
            )
            // The cause is the ticks and dims right below, so the
            // reason sits beside the well, outside its grey (#815).
            if paint.idle != nil {
                Text(idleReason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Why the well has nothing to write: no row is ticked, or
    /// every ticked row is dimmed.
    private var idleReason: String {
        paint.idle == .allTickedDimmed
            ? Self.allDimmedHelp : Self.noneHelp
    }

    static var help: String {
        L(
            "colors.ticked_rows.help",
            "Sets every ticked row to this color. Each row keeps its "
                + "own transparency, and a dimmed row is left as it is."
        )
    }

    static var mixedHelp: String {
        L(
            "colors.ticked_rows.mixed_help",
            "The ticked rows are different colors right now. A color "
                + "here sets all of them."
        )
    }

    static var mixedWord: String { L("colors.mixed", "mixed") }

    static var noneHelp: String {
        L("colors.ticked_rows.none", "Tick a row to give it this color.")
    }

    static var allDimmedHelp: String {
        L(
            "colors.ticked_rows.all_dimmed",
            "Every ticked row is dimmed, so there is nothing to color "
                + "right now."
        )
    }
}

/// A row's tick into its group's colour, or the room for one
/// where the row follows another colour and is never written.
struct RoleTickBox: View {
    let role: ColorRole
    let key: SettingKey
    let tickable: Bool
    let isOn: Binding<Bool>

    var body: some View {
        if tickable {
            Toggle("", isOn: isOn)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .accessibilityLabel(
                    L(
                        "colors.include_row.a11y",
                        "Include %1$@ in %2$@",
                        SettingsCensusLabel.label(for: key) ?? key.id,
                        role.control.text
                    )
                )
        } else {
            Color.clear
                .frame(width: 14, height: 14)
                .accessibilityHidden(true)
        }
    }
}
