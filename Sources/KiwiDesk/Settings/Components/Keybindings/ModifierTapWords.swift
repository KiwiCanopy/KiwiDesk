import Foundation
import KiwiDeskCore

/// A modifier tap in words (#1872): "Command, press twice",
/// "Right Option, press twice", "Right Command, press once" — what
/// VoiceOver and the hover say for a drawn `⌘⌘`, `Right ⌥⌥`,
/// `Right ⌘`. The side word is the catalog's chord frame.
@MainActor
enum ModifierTapWords {
    /// `combo` in words, nil for a chord.
    static func spoken(_ combo: KeyCombo) -> String? {
        guard let count = combo.tapCount, let kind = combo.tapKind
        else { return nil }
        let name =
            combo.modifiers.side(of: kind).map {
                ChordGlyphs.word($0, Self.name(kind))
            } ?? Self.name(kind)
        return count == 1
            ? L("chord.tap.once", "%1$@, press once", name)
            : L("chord.tap.twice", "%1$@, press twice", name)
    }

    static func name(_ kind: ModifierKind) -> String {
        switch kind {
        case .control: L("chord.tap.control", "Control")
        case .option: L("chord.tap.option", "Option")
        case .shift: L("chord.tap.shift", "Shift")
        case .command: L("chord.tap.command", "Command")
        }
    }

    /// The hint under a recorder waiting out a single tap of
    /// `pending`: the double tap one more press records.
    static func tapAgain(
        _ pending: KeyCombo,
        sidesKept: Bool
    ) -> String? {
        guard let kind = pending.tapKind,
            let double = KeyCombo.tap(
                kind,
                side: sidesKept ? pending.modifiers.side(of: kind) : nil,
                count: 2
            )
        else { return nil }
        return L(
            "key_recorder.tap_again",
            "Tap again for %1$@",
            ChordGlyphs.render(double, layoutChar: { _ in nil })
        )
    }
}
