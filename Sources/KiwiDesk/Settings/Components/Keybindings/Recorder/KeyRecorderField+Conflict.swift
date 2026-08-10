import KiwiDeskCore
import SwiftUI

/// The row's conflict badge — a BUTTON now (owner 2026-08-10):
/// the ⚠️ carried its sentence in a hover-only `.help`, and a
/// tooltip is not an affordance anyone finds by clicking. The
/// click opens the same sentence in a popover, so the answer is
/// reachable by mouse, and the banner at the top of the section
/// stays the dismissible whole-config summary. Split from
/// `KeyRecorderField.swift`, which sits at the §2.1 ceiling.
extension KeyRecorderField {
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
                    .foregroundStyle(SettingsTheme.warningInk)
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
}
