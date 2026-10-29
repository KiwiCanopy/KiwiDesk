import KiwiDeskCore
import SwiftUI

/// KiwiHub's three keys on Simple (#2737 ruling 6), shown and not
/// edited: KiwiHub is the way to every other shortcut, so its keys
/// stay what the tour taught. Changing them is Advanced's.
struct SimpleKiwiHubKeys: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HomeGroupHeading(L("kiwihub.name", "KiwiHub"))
            HStack(spacing: 16) {
                ForEach(Self.sides, id: \.scope) { side in
                    key(side)
                }
            }
            CrossReferenceRow(
                prose: Self.changeProse,
                linkTitle: SettingsDestination.shortcuts.title,
                destination: .shortcuts
            )
        }
    }

    private struct Side {
        let scope: JumpScope
        let command: NavCommand
    }

    /// The sides in the order of their keys, J K L
    /// (`ShortcutsRowOrder.kiwiHubAtRest`).
    private static let sides = [
        Side(scope: .windows, command: KeybindingCatalog.jumpToWindow),
        Side(scope: .shortcuts, command: KeybindingCatalog.showShortcuts),
        Side(scope: .view, command: KeybindingCatalog.showLayoutPicker),
    ]

    private func key(_ side: Side) -> some View {
        let chord = chord(of: side.command)
        return HStack(spacing: 6) {
            Text(side.scope.title)
                .foregroundStyle(SettingsTheme.ink)
            Text(verbatim: chord ?? "—")
                .font(.callout.monospaced())
                .foregroundStyle(SettingsTheme.ink2)
        }
        .font(.callout)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(side.scope.title)
        .accessibilityValue(
            chord.map(SidedChordWords.label)
                ?? L("simple.kiwihub.unbound", "No key")
        )
        .help(chord.map(SidedChordWords.help) ?? "")
    }

    /// The default layer's chord for `command`, drawn as glyphs.
    private func chord(of command: NavCommand) -> String? {
        model.config.layers.first(where: \.isDefault)?.bindings
            .first { command.runs($0.lua) && !$0.combo.isEmpty }
            .map { ShortcutsReferenceBuilder.glyphs($0.combo) }
    }

    /// The way to change them, its link at the slot.
    @MainActor static var changeProse: String {
        L(
            "simple.kiwihub.change",
            "Change these keys in %1$@ in %2$@.",
            CrossReferenceRow.linkSlot,
            SettingsRootSwitch.advancedTitle
        )
    }
}
