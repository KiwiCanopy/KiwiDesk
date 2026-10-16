import KiwiDeskCore
import SwiftUI

/// One item on the View side's Profile or KiwiVision line (#2309):
/// its name, a ✓ where it is current, its shortcut and, greyed,
/// why it cannot be applied. Its ⌘ number shows in a slot every
/// chip reserves, so holding ⌘ never reflows the line; at rest the
/// name sits centred in the same width (ruling 5).
struct ViewChip: View {
    let item: ViewPickList.Item
    let line: ViewPickList.Line
    let number: Int?
    let isSelected: Bool
    let isDimmed: Bool
    let showsNumber: Bool
    let onActivate: () -> Void
    let onHover: () -> Void

    /// The number slot, wide enough for "⌘9" at the chip's size.
    static let slot: CGFloat = 22
    static let font = Font.system(size: 12)

    var body: some View {
        Button(action: onActivate) { content }
            .buttonStyle(.plain)
            .focusable(false)
            .accessibilityLabel(ViewPickText.spoken(item, on: line))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityHint(
                number.map { LayoutPickText.chordHint("⌘\($0)") } ?? ""
            )
            .onContinuousHover { phase in
                if case .active = phase { onHover() }
            }
    }

    private var badgeShown: Bool { showsNumber && number != nil }

    private var content: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(verbatim: number.map { "⌘\($0)" } ?? "")
                .font(.system(size: 11).monospacedDigit())
                // One line even in the half slot it rests in, or
                // the hidden number wraps and pads the chip.
                .lineLimit(1)
                .foregroundStyle(secondaryInk)
                .opacity(badgeShown ? 1 : 0)
                .frame(
                    width: badgeShown ? Self.slot : Self.slot / 2,
                    alignment: .leading
                )
                .accessibilityHidden(true)
            label
            // Zero height: a bare `Color` takes all the height it is
            // offered and sinks the baseline-aligned name with it.
            Color.clear.frame(width: badgeShown ? 0 : Self.slot / 2, height: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(ground)
        .opacity(isDimmed ? 0.35 : 1)
        .contentShape(Capsule())
    }

    private var label: some View {
        HStack(spacing: 4) {
            if item.isCurrent {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
            }
            Text(item.name).lineLimit(1)
            if let chord = item.chord {
                Text(chord).foregroundStyle(secondaryInk)
            }
            if let refusal = item.refusal {
                Text(refusal).foregroundStyle(secondaryInk)
            }
        }
        .font(Self.font)
        .foregroundStyle(ink)
        .fixedSize()
    }

    private var ink: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(SettingsTheme.accentInk) }
        return item.isApplicable
            ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary)
    }

    private var secondaryInk: AnyShapeStyle {
        isSelected
            ? AnyShapeStyle(SettingsTheme.accentInk.opacity(0.75))
            : AnyShapeStyle(.secondary)
    }

    @ViewBuilder private var ground: some View {
        if isSelected {
            Capsule().fill(SettingsTheme.accent)
        } else {
            Capsule().strokeBorder(.separator)
        }
    }
}
