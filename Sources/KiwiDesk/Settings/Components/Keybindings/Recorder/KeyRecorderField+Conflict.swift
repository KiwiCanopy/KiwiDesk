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
/// popover: the chord outlined in `danger`, a worded caption in
/// the recorder's own caption slot, and the badge in `danger`
/// too — three channels, none of them colour alone
/// (`ConflictRowTreatmentTests`).
extension KeyRecorderField {
    /// Whether the row cannot fire as things stand.
    var isDead: Bool { severity?.isDead == true }

    var conflictBadge: some View {
        iconSlot {
            if let conflict {
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
                .help(conflict)
                .accessibilityLabel(conflict)
                .popover(
                    isPresented: $conflictPopoverShown,
                    arrowEdge: .bottom
                ) {
                    Text(conflict)
                        .font(.callout)
                        .foregroundStyle(SettingsTheme.ink)
                        .padding(14)
                        .frame(maxWidth: 320)
                }
            }
        }
    }

    /// The dead row's caption: the same sentence the badge
    /// carries, in the flow (`KeyRecorderRejectionRow`'s idiom).
    /// Hidden from VoiceOver — the record button's value already
    /// speaks it, and the badge's label does too.
    @ViewBuilder var deadCaption: some View {
        if isDead, let conflict {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(conflict)
            }
            .font(.caption)
            .foregroundStyle(SettingsTheme.danger)
            .accessibilityHidden(true)
        }
    }
}
