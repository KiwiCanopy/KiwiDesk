import KiwiDeskCore
import SwiftUI

/// The pocket's place along its edge on KiwiShelf's card (#2678,
/// 2026-10-29 ruling); its edge is Position's (#3376).
extension KiwiShelfCard {
    /// The rule a bar's edge sets: shown under the row while the
    /// pocket shares one, and in the `?` otherwise (#3376).
    static var pocketPositionNote: String {
        L(
            "kiwishelf.pocket_position.help",
            "On a bar's edge, the Pocket takes the bar's nearer end."
        )
    }

    /// Whether the note shows under the row rather than in its `?`.
    var pocketNoteShown: Bool {
        model.config.settings.pocketSharesABarEdge
    }

    @ViewBuilder var pocketPositionRows: some View {
        pocketPositionRow
        if pocketNoteShown {
            BarNoteRow(text: Self.pocketPositionNote)
        }
    }

    private var pocketPositionRow: some View {
        let label = SettingsCatalog.bars.kiwishelfPocketPosition.text
        let readout = SettingsValueReadout.percent(
            Double(shelf.wrappedValue.pocketPosition) / 100
        )
        return SettingsRowShape {
            SettingsRowLabel(
                label: label,
                help: pocketNoteShown ? nil : Self.pocketPositionNote
            )
        } control: {
            HStack(spacing: 6) {
                SettingsSlider(
                    value: Binding(
                        get: { Double(shelf.wrappedValue.pocketPosition) },
                        set: {
                            shelf.wrappedValue.pocketPosition =
                                KiwiShelf.clampPocketPosition(CGFloat($0))
                        }
                    ),
                    range: 0...100,
                    step: 1,
                    label: label,
                    spokenValue: PocketGroup.spokenPosition(
                        readout,
                        edge: shelf.wrappedValue.pocketEdge
                    ),
                    ends: PocketGroup.ends(shelf.wrappedValue.pocketEdge)
                )
                Text(readout)
                    .monospacedDigit()
                    .accessibilityHidden(true)
            }
        }
        .searchAnchored(SettingsCatalog.bars.kiwishelfPocketPosition)
    }
}
