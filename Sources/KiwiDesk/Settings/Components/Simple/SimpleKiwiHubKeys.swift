import KiwiDeskCore
import SwiftUI

/// KiwiHub's three keys on Simple (#2777 rulings 3–5), shown and
/// not edited: each side's glyph — the one its Shortcuts row
/// wears — and name over its chord as keycaps, in three equal
/// columns. KiwiHub is the way to every other shortcut, so its keys
/// stay what the tour taught; changing them is Advanced's, which
/// the hover names.
struct SimpleKiwiHubKeys: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        SimpleCard(
            title: L("kiwihub.name", "KiwiHub"),
            caption: L(
                "simple.kiwihub.caption",
                "Every other shortcut starts here"
            ),
            plated: false
        ) {
            // A long translation stacks the sides.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) { tiles }
                VStack(alignment: .leading, spacing: 14) { tiles }
            }
            .padding(.top, 4)
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
        ForEach(Self.sides, id: \.scope) {
            tile($0).frame(maxWidth: .infinity)
        }
    }

    private func tile(_ side: Side) -> some View {
        let combo = combo(of: side.command)
        let chord = combo.map(ShortcutsReferenceBuilder.glyphs)
        return VStack(spacing: 8) {
            // The side, by the glyph its Shortcuts row wears and its
            // name, over its keys.
            HStack(spacing: 6) {
                ShortcutsReferenceBuilder.icon(for: side.command).map {
                    Image(systemName: $0)
                }
                Text(side.scope.title)
            }
            .font(.callout)
            .foregroundStyle(SettingsTheme.ink2)
            if let combo {
                HStack(spacing: 5) {
                    ForEach(
                        Array(Self.caps(combo).enumerated()),
                        id: \.offset
                    ) { index, cap in
                        if index > 0 { ChordKeycap.plus }
                        ChordKeycap(text: cap.glyph, side: cap.side)
                    }
                }
            } else {
                Text(L("simple.kiwihub.unbound", "No key"))
                    .foregroundStyle(SettingsTheme.ink3)
                    .padding(.vertical, 4)
            }
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(side.scope.title)
        .accessibilityValue(
            chord.map(SidedChordWords.label)
                ?? L("simple.kiwihub.unbound", "No key")
        )
        .help(
            chord.map { SidedChordWords.help($0) + "\n" + Self.changeHelp }
                ?? Self.changeHelp
        )
    }

    /// Where the keys change, on the pointer only (#2777 ruling 5).
    @MainActor static var changeHelp: String {
        L(
            "simple.kiwihub.change_help",
            "Change in %1$@ in %2$@",
            SettingsDestination.shortcuts.title,
            SettingsRootSwitch.advancedTitle
        )
    }

    /// The default layer's combo for `command`.
    private func combo(of command: NavCommand) -> String? {
        model.config.layers.first(where: \.isDefault)?.bindings
            .first { command.runs($0.lua) && !$0.combo.isEmpty }?
            .combo
    }

    /// A combo's keycaps: one per modifier, a sided modifier
    /// carrying its run's side word, then the key — one rule for
    /// every chord (#2777 ruling 4).
    @MainActor static func caps(
        _ combo: String
    ) -> [(glyph: String, side: String?)] {
        guard let parsed = KeyCombo.parse(combo) else {
            return [(combo, nil)]
        }
        let drawn = ChordGlyphs.render(
            parsed,
            layoutChar: LayoutKeyGlyph.char
        )
        let mods = ChordGlyphs.modifiers(parsed.modifiers)
        let separator = ChordGlyphs.separator(parsed.modifiers)
        let key = String(drawn.dropFirst(mods.count + separator.count))
        var caps: [(glyph: String, side: String?)] = []
        var word: String?
        for token in mods.split(separator: " ") {
            let glyphs = token.filter { ChordGlyphs.kinds[$0] != nil }
            if glyphs.count == token.count {
                caps += glyphs.map { (String($0), word) }
                word = nil
            } else {
                word = String(token)
            }
        }
        return caps + [(key, nil)]
    }
}
