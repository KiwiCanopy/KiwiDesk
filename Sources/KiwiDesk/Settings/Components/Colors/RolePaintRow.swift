import KiwiDeskCore
import SwiftUI

/// A role group's colour (#1857): one well over the ticked rows,
/// a `?` and a "mixed" readout while they differ (#1383's shape),
/// greyed while no row is ticked.
struct RolePaintRow: View {
    let role: ColorRole
    let paint: RolePaint
    /// The well's value: the first target's colour, writing every
    /// target (`RolePaint.painted`).
    let hex: Binding<String>

    var body: some View {
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
            .accessibilityValue(
                paint.mixed ? Self.mixedWord : paint.wellHex
            )
            if paint.mixed {
                HelpButton(
                    explanation: Self.mixedHelp,
                    subject: role.control.text
                )
                Text(Self.mixedWord)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .accessibilityHidden(true)
            }
        }
        .modifier(
            GreyOut(active: paint.targets.isEmpty, help: Self.noneHelp)
        )
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
