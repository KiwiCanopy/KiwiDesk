import KiwiDeskCore
import SwiftUI

/// A modifier drag's modifier recorder (#2447): the shared
/// `ModifierChordRecorder` with the drags' own refusals — a lone
/// modifier, or the other drag's chord.
struct ModifierDragRecorderField: View {
    /// VoiceOver's name for the field.
    let name: String
    @Binding var chord: ScrollChord
    /// The other action's chord, which this one may not take.
    let other: ScrollChord
    let otherAction: ModifierDragAction

    var body: some View {
        ModifierChordRecorder(
            name: name,
            chord: $chord,
            recordHelp: L(
                "shortcuts.gestures.modifier_drag.help",
                "Hold any of ⌃ Control, ⌥ Option, ⇧ Shift, and "
                    + "⌘ Command, then let go — the keys you held "
                    + "together are recorded."
            ),
            clearHelp: L(
                "shortcuts.gestures.modifier_drag.clear",
                "Turn this drag off"
            ),
            refuse: {
                ModifierDragRefusal.of($0, other: other, heldBy: otherAction)
            },
            announcement: Self.caption
        ) { refusal in
            Text(Self.caption(refusal))
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The sentence under the field for a refused chord.
    @MainActor static func caption(_ refusal: ModifierDragRefusal) -> String {
        switch refusal {
        case .otherAction(.move):
            return L(
                "shortcuts.gestures.modifier_drag.refused_move",
                "These keys already move windows."
            )
        case .otherAction(.resize):
            return L(
                "shortcuts.gestures.modifier_drag.refused_resize",
                "These keys already resize windows."
            )
        }
    }
}
