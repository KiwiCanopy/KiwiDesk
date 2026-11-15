import KiwiDeskCore
import SwiftUI

/// Inline conflict row showing Steal / Go to actions (#34).
struct KeyRecorderRejectionRow: View {
    let rejection: RecorderRejection
    let onSteal: () -> Void
    let onGoTo: () -> Void
    let onDismiss: () -> Void

    /// One line where it fits; else the sentence wraps, its
    /// holder whole, and the actions follow on a line of their own
    /// (#3258).
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                message
                actions
            }
            VStack(alignment: .leading, spacing: 4) {
                message
                HStack(spacing: 6) { actions }
            }
        }
        .font(.caption)
    }

    private var message: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            // Shape cue beside the red text — the conflict must
            // not read by colour alone (WCAG 1.4.1); hidden from
            // VoiceOver, the text states it. `danger`, not
            // `.red`: system red sinks on the theme's dark card.
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(SettingsTheme.danger)
                .accessibilityHidden(true)
            Text(assigned)
                .foregroundStyle(SettingsTheme.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var actions: some View {
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

    /// The row with its actions, each of which ends the offer
    /// through `clear` first: Steal, Go to and the dismissal.
    static func wired(
        _ rejection: RecorderRejection,
        coordinator: RecorderCoordinator,
        clear: @escaping () -> Void
    ) -> Self {
        KeyRecorderRejectionRow(
            rejection: rejection,
            onSteal: {
                clear()
                rejection.steal()
            },
            onGoTo: {
                clear()
                coordinator.scrollTarget = rejection.holderRowID
            },
            onDismiss: clear
        )
    }

    private var assigned: String {
        rejection.inStep
            ? L(
                "key_recorder.assigned_to_in_step",
                "Assigned to \u{201C}%1$@\u{201D} at this point in "
                    + "the sequence",
                rejection.holder
            )
            : L(
                "key_recorder.assigned_to",
                "Assigned to \u{201C}%1$@\u{201D}",
                rejection.holder
            )
    }
}

/// A `ShortcutKeyRow`'s conflict line. The coordinator is read here,
/// not in the row, which an `.equatable()` row draws (#2783).
struct RecorderConflictLine: View {
    let rejection: RecorderRejection
    let clear: () -> Void
    @EnvironmentObject private var coordinator: RecorderCoordinator

    var body: some View {
        KeyRecorderRejectionRow.wired(
            rejection,
            coordinator: coordinator,
            clear: clear
        )
    }
}
