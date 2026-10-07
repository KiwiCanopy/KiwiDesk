import KiwiDeskCore
import SwiftUI

/// The pinned jump bar over Shortcuts & Gestures (#1520): one chip
/// per group, wrapping rather than scrolling, each line centred,
/// and the edited layer's name on a centred line under them
/// (owner, amendment 5). It sits on the page ground, and draws its
/// lower hairline once content slides under it.
struct ShortcutsJumpBar: View {
    let marked: ShortcutsJumpGroup?
    let underlapped: Bool
    /// "Editing the “x” layer", or nil where there is no choice.
    let readout: String?
    /// The same sentence with the layer's full name, for
    /// VoiceOver; nil speaks what is drawn.
    var spokenReadout: String? = nil
    let jump: (ShortcutsJumpGroup) -> Void
    @Environment(\.settingsWidth) private var width

    /// Gaps between chips and between wrapped lines.
    static let spacing: CGFloat = 6

    /// The longest layer name the readout spells whole; a longer
    /// one is cut inside the sentence, never the sentence itself.
    static let nameLimit = 32

    /// `name`, cut to `nameLimit` with an ellipsis.
    static func shownName(_ name: String) -> String {
        guard name.count > nameLimit else { return name }
        return String(name.prefix(nameLimit - 1)) + "…"
    }

    var body: some View {
        content
            // Full width in every arrangement, so the ground and
            // the hairline span the pane.
            .frame(maxWidth: .infinity)
            .padding(.horizontal, SettingsMetrics.paneInset)
            .padding(.vertical, 10)
            .background(SettingsTheme.page)
            .overlay(alignment: .bottom) {
                if underlapped {
                    SettingsTheme.hairline.frame(height: 1)
                }
            }
    }

    /// Header chrome, so it goes with the chrome step.
    private var shownReadout: String? {
        width.collapsesChrome ? nil : readout
    }

    /// Always a line of its own under the chips, wrapping rather
    /// than eliding.
    private var content: some View {
        VStack(alignment: .center, spacing: Self.spacing) {
            chips
            if let shownReadout {
                readoutText(shownReadout)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func readoutText(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(SettingsTheme.ink2)
            .accessibilityLabel(spokenReadout ?? text)
    }

    private var chips: some View {
        FlowLayout(spacing: Self.spacing, alignment: .center) {
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
                    .frame(width: 1, height: 18)
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

/// A content-sized capsule at the large-control height, its label
/// at the size of the header it jumps to (owner amendments 2 and
/// 3, #1520). Marked: a soft accent fill and a semibold label in
/// neutral ink, its width reserved so the marking never reflows
/// the row.
struct ShortcutsJumpChip: View {
    let title: String
    let marked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
        }
        .buttonStyle(ShortcutsJumpChipStyle(marked: marked))
        .accessibilityAddTraits(marked ? .isSelected : [])
    }

    /// The semibold width is reserved under either weight.
    private var label: some View {
        ZStack {
            text(.semibold).hidden().accessibilityHidden(true)
            text(marked ? .semibold : .regular)
        }
    }

    private func text(_ weight: Font.Weight) -> some View {
        Text(title)
            .font(.body.weight(weight))
            .foregroundStyle(SettingsTheme.ink)
            .lineLimit(1)
            .fixedSize()
    }

    /// The chip's own shape, answering the pointer alone; beneath
    /// the marking (#1520 amendments 4 and 5).
    static func restFill(pressed: Bool, hovered: Bool) -> Color {
        if pressed { return SettingsTheme.chipPressed }
        return hovered ? SettingsTheme.chipHover : SettingsTheme.chipRest
    }

    /// The marking's layer, over the pointer's.
    static func markFill(_ marked: Bool) -> Color {
        SettingsTheme.accent.opacity(
            marked ? SettingsTheme.jumpChipMarkedOpacity : 0
        )
    }
}

/// The jump chip's face: the pointer's layer beneath the marking's
/// — each a function of its own state alone, so neither a hover
/// nor a press can erase the marking (#1173) — under an edge that
/// no state moves. No animation, no shadow (#1520 amendment 5).
struct ShortcutsJumpChipStyle: ButtonStyle {
    let marked: Bool

    func makeBody(configuration: Configuration) -> some View {
        Face(configuration: configuration, marked: marked)
    }

    /// A real `View`, so the hover is state it can hold.
    private struct Face: View {
        let configuration: Configuration
        let marked: Bool
        @State private var hovered = false

        var body: some View {
            configuration.label
                .background {
                    ZStack {
                        Capsule().fill(
                            ShortcutsJumpChip.restFill(
                                pressed: configuration.isPressed,
                                hovered: hovered
                            )
                        )
                        Capsule().fill(ShortcutsJumpChip.markFill(marked))
                    }
                }
                .overlay {
                    Capsule().strokeBorder(
                        SettingsTheme.chipEdge,
                        lineWidth: 1
                    )
                }
                .contentShape([.interaction, .focusEffect], Capsule())
                .onHover { hovered = $0 }
        }
    }
}
