import KiwiDeskCore
import SwiftUI

/// The Sides pull-down before the well (#2614): while *Tell left
/// and right modifiers apart* is on, each sided modifier of the
/// recorded shortcut can be put on its left key, its right key or
/// either side, at rest. The slot is held on every row while the
/// switch is on, so the wells line up; a pick commits through the
/// same preflight a recording does.
extension KeyRecorderField {
    @ViewBuilder var sidesSlot: some View {
        if recorderSides != nil {
            iconSlot {
                if !recording, let parsed = KeyCombo.parse(combo),
                    !parsed.pickableSideKinds.isEmpty
                {
                    sidesMenu(parsed)
                }
            }
        }
    }

    private func sidesMenu(_ parsed: KeyCombo) -> some View {
        Menu {
            ForEach(parsed.pickableSideKinds, id: \.self) { kind in
                Section(Self.sectionTitle(kind)) {
                    ForEach(Self.choices, id: \.self) { side in
                        if let picked = parsed.pickingSide(side, of: kind) {
                            Button {
                                pickSide(picked)
                            } label: {
                                Self.choiceLabel(
                                    side,
                                    kind: kind,
                                    current: parsed.modifiers.side(of: kind)
                                )
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.left.and.right")
                .foregroundStyle(SettingsTheme.ink2)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(Self.sidesHelp)
        .accessibilityLabel(
            L("key_recorder.sides.label", "Sides for %1$@", name)
        )
    }

    /// Left, Right, then Either side (nil).
    static let choices: [ModifierSide?] = [.left, .right, nil]

    private func pickSide(_ picked: KeyCombo) {
        guard let text = picked.comboString(), text != combo else {
            return
        }
        commit(text)
    }

    /// A section's title: the modifier's glyph and its name.
    static func sectionTitle(_ kind: ModifierKind) -> String {
        ComboSymbols.glyph(of: kind) + " " + ModifierTapWords.name(kind)
    }

    /// One choice, checked where it is the row's own.
    @ViewBuilder static func choiceLabel(
        _ side: ModifierSide?,
        kind: ModifierKind,
        current: ModifierSide?
    ) -> some View {
        let text = choiceText(side, kind: kind)
        if side == current {
            Label(text, systemImage: "checkmark")
        } else {
            Text(text)
        }
    }

    static func choiceText(_ side: ModifierSide?, kind: ModifierKind) -> String
    {
        guard let side else { return eitherSide }
        return ChordGlyphs.word(side, ComboSymbols.glyph(of: kind))
    }

    /// The Either side item, which the sides row's help names.
    @MainActor static var eitherSide: String {
        L("key_recorder.sides.either", "Either side")
    }

    @MainActor static var sidesHelp: String {
        L("key_recorder.sides.help", "Choose the side of each modifier")
    }
}
