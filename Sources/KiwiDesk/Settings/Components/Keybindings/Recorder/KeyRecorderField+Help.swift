import KiwiDeskCore
import SwiftUI

/// The recorder's hover help: how recording works, with sides kept
/// or not, taps included (#1872).
extension KeyRecorderField {
    /// The help with sides kept: one frame, so no translation has
    /// to join two sentences (localization.md).
    @MainActor static var recordSidesHelp: String {
        L(
            "key_recorder.help_press_sides",
            "A shortcut is one key plus any of "
                + "⌃ Control, ⌥ Option, ⇧ Shift, "
                + "and ⌘ Command — it locks in the "
                + "moment you press the key. Tap a modifier "
                + "alone to record the tap: twice for any "
                + "modifier, once for a left or right one. Add "
                + "a layer to give one key a second meaning. "
                + "The side "
                + "you press is kept: %1$@ is recorded as %2$@.",
            HyperKeyWords.name(.rightCommand),
            ModifierSidesWords.drawn(.right)
        )
    }

    // Computed: a localized value stored for the life of the
    // process keeps the locale it was first read in (#1311).
    @MainActor static var recordHelp: String {
        L(
            "key_recorder.help_press",
            "A shortcut is one key plus any of "
                + "⌃ Control, ⌥ Option, ⇧ Shift, "
                + "and ⌘ Command — it locks in the "
                + "moment you press the key. Tap a modifier "
                + "alone to record the tap: twice for any "
                + "modifier, once for a left or right one. Add "
                + "a layer to give one key a second meaning."
        )
    }
}
