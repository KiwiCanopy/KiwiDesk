import KiwiDeskCore
import SwiftUI

/// Inline conflict row showing Steal / Go to actions (#34).
struct KeyRecorderRejectionRow: View {
    let rejection: RecorderRejection
    let onSteal: () -> Void
    let onGoTo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            // Visual cue for conflict state (WCAG 1.4.1).
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
                .buttonStyle(.link)
                .pointingHandCursor()
            Button(L("key_recorder.go_to", "Go to"), action: onGoTo)
                .buttonStyle(.link)
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
    }
}
