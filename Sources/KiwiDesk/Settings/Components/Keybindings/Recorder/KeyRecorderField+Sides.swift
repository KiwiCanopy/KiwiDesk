import KiwiDeskCore
import SwiftUI

/// The Sides pull-down before the well (#2614): while *Tell left
/// and right modifiers apart* is on, each sided modifier of the
/// recorded shortcut can be put on its left key, its right key or
/// either side, at rest. The slot is held on every row while the
/// switch is on, so the wells line up (`footprint` holds it too); a
/// pick commits through `commit`, the preflight a recording takes.
extension KeyRecorderField {
    @ViewBuilder var sidesSlot: some View {
        if let sides = recorderSides {
            iconSlot {
                if !recording, let parsed = KeyCombo.parse(combo),
                    !parsed.pickableSideKinds(hyperKey: sides.hyperKey)
                        .isEmpty
                {
                    sidesMenu(parsed, hyperKey: sides.hyperKey)
                }
            }
        }
    }

    private func sidesMenu(
        _ parsed: KeyCombo,
        hyperKey: HyperSourceKey?
    ) -> some View {
        Menu {
            ForEach(
                parsed.pickableSideKinds(hyperKey: hyperKey),
                id: \.self
            ) { kind in
                Picker(
                    Self.sectionTitle(kind),
                    selection: Binding(
                        get: { parsed.modifiers.side(of: kind) },
                        set: { side in
                            pickSide(side, of: kind, in: parsed, hyperKey)
                        }
                    )
                ) {
                    ForEach(Self.choices, id: \.self) { side in
                        if parsed.pickingSide(
                            side,
                            of: kind,
                            hyperKey: hyperKey
                        )
                            != nil
                        {
                            Text(Self.choiceText(side)).tag(side)
                        }
                    }
                }
                .pickerStyle(.inline)
            }
        } label: {
            Label(Self.sidesLabel(name), systemImage: "arrow.left.and.right")
                .labelStyle(.iconOnly)
        }
        .menuStyle(.borderlessButton)
        .neutralMenuLabel()
        .menuIndicator(.hidden)
        .fixedSize()
        .iconHoverChip()
        .help(Self.sidesHelp)
        .accessibilityLabel(Self.sidesLabel(name))
        .accessibilityValue(SidedChordWords.label(label))
    }

    /// Left, Right, then Either side (nil).
    static let choices: [ModifierSide?] = [.left, .right, nil]

    /// Commits `side` for `kind`, unless it is the row's own: a
    /// stored spelling the canonical form differs from is no edit.
    private func pickSide(
        _ side: ModifierSide?,
        of kind: ModifierKind,
        in parsed: KeyCombo,
        _ hyperKey: HyperSourceKey?
    ) {
        guard
            let picked = parsed.pickingSide(
                side,
                of: kind,
                hyperKey: hyperKey
            ),
            picked != parsed, let text = picked.comboString()
        else { return }
        commit(text)
    }

    /// A section's title: the modifier's glyph and its name.
    static func sectionTitle(_ kind: ModifierKind) -> String {
        ComboSymbols.glyph(of: kind) + " " + ModifierTapWords.name(kind)
    }

    /// One choice under its modifier's title: the side's word, or
    /// Either side.
    static func choiceText(_ side: ModifierSide?) -> String {
        side.map(ChordGlyphs.sideWord) ?? eitherSide
    }

    /// The Either side item, which the sides row's help names.
    @MainActor static var eitherSide: String {
        L("key_recorder.sides.either", "Either side")
    }

    static func sidesLabel(_ name: String) -> String {
        L("key_recorder.sides.label", "Sides for %1$@", name)
    }

    @MainActor static var sidesHelp: String {
        L("key_recorder.sides.help", "Choose the side of each modifier")
    }
}
