import KiwiDeskCore
import SwiftUI

/// The pinned jump bar over Shortcuts & Gestures (#1520): one chip
/// per group, wrapping rather than scrolling, and the edited
/// layer's name at the trailing end. It sits on the page ground,
/// and draws its lower hairline once content slides under it.
struct ShortcutsJumpBar: View {
    let marked: ShortcutsJumpGroup?
    let underlapped: Bool
    /// "Editing the “x” layer", or nil where there is no choice.
    let readout: String?
    let jump: (ShortcutsJumpGroup) -> Void
    @Environment(\.settingsWidth) private var width

    /// Gaps between chips and between wrapped lines.
    static let spacing: CGFloat = 6

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            chips
            Spacer(minLength: 0)
            // Header chrome, so it goes with the chrome step.
            if let readout, !width.collapsesChrome {
                Text(readout)
                    .font(.subheadline)
                    .foregroundStyle(SettingsTheme.ink2)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .padding(.horizontal, SettingsMetrics.paneInset)
        .padding(.vertical, 8)
        .background(SettingsTheme.page)
        .overlay(alignment: .bottom) {
            if underlapped {
                SettingsTheme.hairline.frame(height: 1)
            }
        }
    }

    private var chips: some View {
        FlowLayout(spacing: Self.spacing) {
            ForEach(ShortcutsJumpGroup.allCases, id: \.self) { group in
                chipRun(group)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            L("shortcuts.jump.label", "Jump to")
        )
    }

    /// A rule rides the chip it follows, so a wrap can never start
    /// a line with it.
    @ViewBuilder private func chipRun(
        _ group: ShortcutsJumpGroup
    ) -> some View {
        if group.ruledAfter {
            HStack(spacing: Self.spacing) {
                chip(group)
                SettingsTheme.hairline
                    .frame(width: 1, height: 14)
                    .accessibilityHidden(true)
            }
        } else {
            chip(group)
        }
    }

    private func chip(_ group: ShortcutsJumpGroup) -> some View {
        ShortcutsJumpChip(
            title: group.control.text,
            marked: marked == group
        ) {
            jump(group)
        }
    }
}

/// A content-sized hairline capsule. Marked: a soft accent fill
/// and a semibold label in neutral ink. Hover lifts a neutral fill
/// on a layer of its own beneath the marking, which it never
/// replaces (#1173).
struct ShortcutsJumpChip: View {
    let title: String
    let marked: Bool
    let action: () -> Void
    @State private var hovered = false

    /// The marked chip's accent wash over the page ground.
    static let markedWash: Double = 0.18

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(marked ? .semibold : .regular))
                .foregroundStyle(SettingsTheme.ink)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background {
                    ZStack {
                        Capsule().fill(
                            hovered ? SettingsTheme.cardHover : .clear
                        )
                        Capsule().fill(
                            SettingsTheme.accent.opacity(
                                marked ? Self.markedWash : 0
                            )
                        )
                    }
                }
                .overlay {
                    Capsule().strokeBorder(SettingsTheme.hairline)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityAddTraits(marked ? .isSelected : [])
    }
}
