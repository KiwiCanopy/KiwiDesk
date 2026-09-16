import KiwiDeskCore
import SwiftUI

/// The exact shares a split row offers — ¼ ⅓ ½ ⅔ ¾ — as chips
/// under its slider (#1382): a closed set is a chooser, not a
/// parser, and a share is not a count. A chip is pressed when the
/// stored share reads as it at the wire's precision
/// (`ScrollSize.percentString`), so a drag off a preset shows
/// none pressed.
struct FractionChips: View {
    @Binding var value: Double
    /// The row's label, for the group's spoken name.
    let label: String

    /// The five shares, in the order the eye reads them.
    static let shares: [(glyph: String, value: Double)] = [
        ("¼", 0.25), ("⅓", 1.0 / 3), ("½", 0.5),
        ("⅔", 2.0 / 3), ("¾", 0.75),
    ]

    var body: some View {
        HStack(spacing: ChipMetrics.spacing) {
            ForEach(Self.shares, id: \.glyph) { share in
                FractionChip(
                    glyph: share.glyph,
                    selected: Self.matches(value, share.value)
                ) {
                    value = share.value
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            L("ratio.chips", "%1$@ presets", label)
        )
    }

    /// Whether the stored share IS the chip's, judged by the one
    /// wire spelling (`ScrollSize.percentString`), never a
    /// hand-typed tolerance.
    static func matches(_ stored: Double, _ share: Double) -> Bool {
        ScrollSize.percentString(stored)
            == ScrollSize.percentString(share)
    }
}

/// One fraction chip, drawn like `ShortcutLayerChip`: selection
/// is its rest affordance.
private struct FractionChip: View {
    let glyph: String
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(glyph)
                .font(.callout.monospacedDigit())
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Capsule().fill(fill))
                .animation(hoverAnimation, value: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = isEnabled && $0 }
        .onChange(of: isEnabled) { _, now in
            if !now { hovering = false }
        }
        .accessibilityLabel(glyph)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var fill: Color {
        if selected {
            return SettingsTheme.accent.opacity(0.25)
        }
        return Color.secondary.opacity(
            hovering && isEnabled ? 0.18 : 0.12
        )
    }

    private var hoverAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.12)
    }
}
