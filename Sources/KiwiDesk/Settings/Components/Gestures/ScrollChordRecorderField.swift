import KiwiDeskCore
import SwiftUI

/// A scroll gesture's modifier recorder (#1656): the shared
/// `ModifierChordRecorder` with the gestures' own refusals. The
/// other gesture's chord offers Go to, which reveals that
/// gesture's row (#1519 ruling; `+Refusal`).
struct ScrollChordRecorderField: View {
    /// VoiceOver's name for the field.
    let name: String
    @Binding var chord: ScrollChord
    /// The other gesture's chord, which this one may not take,
    /// and that gesture, which the refusal names.
    let other: ScrollChord
    let otherGesture: ScrollGestures.Consumer
    /// Reveals a gesture's recorder, handed `otherGesture`; the
    /// refusal keeps its caption, so the link keeps the focus.
    var reveal: ((ScrollGestures.Consumer) -> Void)?

    var body: some View {
        ModifierChordRecorder(
            name: name,
            chord: $chord,
            recordHelp: L(
                "shortcuts.gestures.scroll.help",
                "Hold two or more of ⌃ Control, ⌥ Option, ⇧ Shift, and "
                    + "⌘ Command, then let go — the keys you held "
                    + "together are recorded."
            ),
            clearHelp: L(
                "shortcuts.gestures.scroll.clear",
                "Turn this gesture off"
            ),
            refuse: {
                ScrollChordRefusal.of($0, other: other, heldBy: otherGesture)
            },
            announcement: Self.caption,
            caption: refusalCaption
        )
    }
}
