import KiwiDeskCore
import SwiftUI

/// The row's conflict badge — a BUTTON now (owner 2026-08-10):
/// the ⚠️ carried its sentence in a hover-only `.help`, and a
/// tooltip is not an affordance anyone finds by clicking. The
/// click opens the same sentence in a popover, so the answer is
/// reachable by mouse, and the banner at the top of the section
/// stays the dismissible whole-config summary. Split from
/// `KeyRecorderField.swift`, which sits at the §2.1 ceiling.
///
/// A DEAD row (#1126) says so in the flow, not only in the
/// popover: the chord outlined in `danger`, a worded caption,
/// and the badge in `danger` too. Every channel reads the ONE
/// `reading`, so none can draw without the words
/// (`ConflictRowTreatmentTests`).
extension KeyRecorderField {
    /// Whether the row cannot fire as things stand.
    var isDead: Bool { reading?.severity.isDead == true }

    /// The sentence every channel shows.
    var conflictSentence: String? { reading?.sentence }

    /// A dead row is never "Active now" (#1126): the outline and
    /// caption say macOS answers the chord, so the live-apply
    /// success caption would contradict them in the same column.
    func showsFeedback(_ feedback: LiveApplyFeedback) -> Bool {
        if case .applied = feedback.status, isDead { return false }
        return true
    }

    var conflictBadge: some View {
        iconSlot {
            if let sentence = conflictSentence {
                Button {
                    conflictPopoverShown = true
                } label: {
                    Image(
                        systemName:
                            "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(
                        isDead
                            ? SettingsTheme.danger
                            : SettingsTheme.warningInk
                    )
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
                .help(sentence)
                .accessibilityLabel(sentence)
                .popover(
                    isPresented: $conflictPopoverShown,
                    arrowEdge: .bottom
                ) {
                    // `fixedSize` before the frame, the idiom
                    // `HelpButton` already uses: without it the
                    // sentence takes an ideal-width proposal and
                    // TRUNCATES to one line instead of wrapping
                    // (owner, on device 2026-09-03).
                    Text(sentence)
                        .font(.callout)
                        .foregroundStyle(SettingsTheme.ink)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                        .frame(
                            maxWidth: 320,
                            alignment: .leading
                        )
                        .padding(14)
                }
            }
        }
    }

    /// The dead row's caption: the same sentence the badge
    /// carries, in the flow (`KeyRecorderRejectionRow`'s idiom).
    /// Hidden from VoiceOver — the record button's value already
    /// speaks it, and the badge's label does too.
    @ViewBuilder var deadCaption: some View {
        if isDead, let sentence = conflictSentence {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(sentence)
            }
            .font(.caption)
            .foregroundStyle(SettingsTheme.danger)
            .accessibilityHidden(true)
        }
    }
}
