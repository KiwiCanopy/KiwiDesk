import KiwiDeskCore
import SwiftUI

/// The recorder's captions beside the well: why a row would not
/// fire as drawn, and what a single tap left (#3257).
extension KeyRecorderField {
    static func rowHint(
        combo: String,
        sidesOn: Bool,
        recording: Bool,
        hyperDormant: Bool
    ) -> String? {
        if hyperDormant { return ShortcutBaseWords.dormantHint }
        if !sidesOn, !recording, let parsed = KeyCombo.parse(combo),
            parsed.modifiers.isSided, !parsed.isTap
        {
            return ModifierSidesWords.eitherSideHint
        }
        return nil
    }

    /// The note a recording leaves (#3257): a single tap, which the
    /// recorder commits only once its gap ran out, never a chord or
    /// a double tap, nor on a row that already held a single tap.
    /// The pending tap is cleared before the outcome arrives, so the
    /// recorded combo is the one input.
    func tapOnceNote(for recorded: String) -> KeyCombo? {
        Self.tapOnceNote(for: recorded, held: combo)
    }

    static func tapOnceNote(for recorded: String, held: String) -> KeyCombo? {
        guard let tap = KeyCombo.parse(recorded), tap.tapCount == 1,
            KeyCombo.parse(held)?.tapCount != 1
        else { return nil }
        return tap
    }

    /// An outside change of the value — a reload, a steal — ends the
    /// note; the field's own commit keeps it.
    func keepTapOnceNote(_ now: String) {
        if !Self.keepsTapOnceNote(tapOnceNote, now: now) {
            tapOnceNote = nil
        }
    }

    /// Whether `note` survives the value becoming `now`: only the
    /// field's own commit of that tap keeps it.
    static func keepsTapOnceNote(_ note: KeyCombo?, now: String) -> Bool {
        guard let note else { return true }
        return KeyCombo.parse(now) == note
    }

    @ViewBuilder var tapOnceCaption: some View {
        if !recording, let note = tapOnceNote,
            let words = ModifierTapWords.tapOnceRecorded(
                note,
                sidesKept: recorderSides != nil
            )
        {
            Text(words.drawn)
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(words.spoken)
        }
    }
}
