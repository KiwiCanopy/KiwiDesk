import KiwiDeskCore
import SwiftUI

/// KiwiHub's three keys on Simple (#2737 ruling 6, re-ruled owner
/// 2026-10-29), shown and not edited: each side's chord as keycaps
/// over its glyph and name, a section of its own with no plate, set
/// off from the cards by a divider. KiwiHub is the way to every
/// other shortcut, so its keys stay what the tour taught; changing
/// them is Advanced's.
struct SimpleKiwiHubKeys: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSection(
                L("kiwihub.name", "KiwiHub"),
                plated: false
            ) {
                // A long translation stacks the sides.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 28) { tiles }
                    VStack(alignment: .leading, spacing: 12) { tiles }
                }
                CrossReferenceRow(
                    prose: Self.changeProse,
                    linkTitle: SettingsDestination.shortcuts.title,
                    destination: .shortcuts
                )
            }
            SettingsTheme.hairline.frame(height: 1)
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

    private var tiles: some View {
        ForEach(Self.sides, id: \.scope) { tile($0) }
    }

    private func tile(_ side: Side) -> some View {
        let combo = combo(of: side.command)
        let chord = combo.map(ShortcutsReferenceBuilder.glyphs)
        return VStack(alignment: .leading, spacing: 6) {
            if let combo {
                HStack(spacing: 5) {
                    ForEach(
                        Array(Self.caps(combo).enumerated()),
                        id: \.offset
                    ) { index, cap in
                        if index > 0 { ChordKeycap.plus }
                        ChordKeycap(text: cap)
                    }
                }
            } else {
                Text(L("simple.kiwihub.unbound", "No key"))
                    .foregroundStyle(SettingsTheme.ink3)
                    .padding(.vertical, 4)
            }
            // The glyph the side's row wears on the Shortcuts page.
            Label {
                Text(side.scope.title)
            } icon: {
                ShortcutsReferenceBuilder.icon(for: side.command).map {
                    Image(systemName: $0)
                }
            }
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

    /// The default layer's combo for `command`.
    private func combo(of command: NavCommand) -> String? {
        model.config.layers.first(where: \.isDefault)?.bindings
            .first { command.runs($0.lua) && !$0.combo.isEmpty }?
            .combo
    }

    /// A combo's keycaps: one per modifier, a sided run kept whole
    /// with its word (`Left ⌃⌥`), then the key.
    @MainActor static func caps(_ combo: String) -> [String] {
        guard let parsed = KeyCombo.parse(combo) else { return [combo] }
        let drawn = ChordGlyphs.render(
            parsed,
            layoutChar: LayoutKeyGlyph.char
        )
        let mods = ChordGlyphs.modifiers(parsed.modifiers)
        let separator = ChordGlyphs.separator(parsed.modifiers)
        let key = String(drawn.dropFirst(mods.count + separator.count))
        let modCaps =
            mods.isEmpty
            ? []
            : separator.isEmpty
                ? mods.map(String.init) : [mods]
        return modCaps + [key]
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
