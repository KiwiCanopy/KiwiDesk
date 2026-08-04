import KiwiDeskCore
import SwiftUI

/// The inline "Assigned to…" row `KeyRecorderField` shows when a
/// lock-in collides with another KiwiDesk row (#34): Steal /
/// Go to are link-styled (`.buttonStyle(.link)`), so they get
/// the pointing-hand cursor explicitly — `.link` sets color but
/// not the cursor. Split out of `KeyRecorderField` to keep that
/// file under the line ceiling.
struct KeyRecorderRejectionRow: View {
    let rejection: RecorderRejection
    let onSteal: () -> Void
    let onGoTo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            // A shape cue beside the red text — the conflict must
            // not read by colour alone (WCAG 1.4.1). Hidden from
            // VoiceOver: the text below already states it.
            //
            // `danger`, not `.red`: system red is tuned against
            // the system window background, and this row sits on
            // the theme's own dark card, where it sinks.
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(SettingsTheme.danger)
                .accessibilityHidden(true)
            Text(
                L(
                    "key_recorder.assigned_to",
                    "Assigned to \u{201C}%1$@\u{201D}",
                    rejection.holder
                )
            )
            .foregroundStyle(SettingsTheme.danger)
            Button(L("key_recorder.steal", "Steal"), action: onSteal)
                .pointingHandCursor()
            Button(L("key_recorder.go_to", "Go to"), action: onGoTo)
                .pointingHandCursor()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(SettingsTheme.ink3)
            .iconButtonAffordance(
                L(
                    "key_recorder.dismiss_conflict",
                    "Dismiss shortcut conflict"
                )
            )
        }
        .font(.caption)
        .buttonStyle(.link)
    }
}
