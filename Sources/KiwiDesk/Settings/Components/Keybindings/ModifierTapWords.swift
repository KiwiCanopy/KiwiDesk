import Foundation
import KiwiDeskCore

/// A modifier tap in words (#1872): "Command, press twice",
/// "Right ⌥, press twice", "Right ⌘, press once" — what VoiceOver
/// and the hover say for a drawn `⌘⌘`, `Right⌥⌥`, `Right⌘`. A sided
/// key takes `HyperKeyWords`' name, whose side word agrees with its
/// key in every catalog, as a sided chord is spoken; never the
/// drawn chord's frame, which stands before glyphs (#3487).
@MainActor
enum ModifierTapWords {
    /// `combo` in words, nil for a chord.
    static func spoken(_ combo: KeyCombo) -> String? {
        guard let count = combo.tapCount, let name = keyName(combo)
        else { return nil }
        return count == 1
            ? L("chord.tap.once", "%1$@, press once", name)
            : L("chord.tap.twice", "%1$@, press twice", name)
    }

    /// The tapped key in words, a sided one by the Hyper card's key
    /// name, which agrees with its key: "Right ⌘".
    static func keyName(_ combo: KeyCombo) -> String? {
        guard let kind = combo.tapKind else { return nil }
        return combo.modifiers.side(of: kind).map {
            HyperKeyWords.name(.key($0, of: kind))
        } ?? Self.name(kind)
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
        guard let double = double(of: pending, sidesKept: sidesKept)
        else { return nil }
        return L(
            "key_recorder.tap_again",
            "Tap again for %1$@",
            drawn(double)
        )
    }

    /// The double tap one more press of `single` records: its side
    /// kept only while sides are.
    static func double(of single: KeyCombo, sidesKept: Bool) -> KeyCombo? {
        guard let kind = single.tapKind else { return nil }
        return KeyCombo.tap(
            kind,
            side: sidesKept ? single.modifiers.side(of: kind) : nil,
            count: 2
        )
    }

    /// The caption a recorded single tap leaves (#3257), drawn and
    /// spoken; nil for anything but a single tap.
    static func tapOnceRecorded(
        _ single: KeyCombo,
        sidesKept: Bool
    ) -> (drawn: String, spoken: String)? {
        guard single.tapCount == 1,
            let double = double(of: single, sidesKept: sidesKept),
            let one = keyName(single), let two = keyName(double)
        else { return nil }
        let drawnLine = L(
            "key_recorder.tap_once_recorded",
            "%1$@ recorded. For %2$@, tap twice within a moment.",
            drawn(single),
            drawn(double)
        )
        // Key names, not the drawn glyphs: a glyph run and a word
        // cannot share one slot in every catalog.
        let spokenLine = L(
            "key_recorder.tap_once_recorded.spoken",
            "Recorded: %1$@, pressed once. For a double press, press "
                + "%2$@ twice within a moment.",
            one,
            two
        )
        return (drawnLine, spokenLine)
    }

    private static func drawn(_ tap: KeyCombo) -> String {
        ChordGlyphs.render(tap, layoutChar: { _ in nil })
    }
}
