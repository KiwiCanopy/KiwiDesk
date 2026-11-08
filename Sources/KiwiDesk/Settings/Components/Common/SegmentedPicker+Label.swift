import SwiftUI

/// A segment's drawn label: its title, and the hint beside it or,
/// on demand, in its place.
extension SegmentedPicker {
    /// A hugging strip sizes each label by the selected weight
    /// whatever the state, so picking never changes its width.
    @ViewBuilder func labelText(
        _ title: String,
        selected: Bool
    ) -> some View {
        let label = Text(title)
            .font(selected ? .body.weight(.semibold) : .callout)
            .lineLimit(1)
        if hugsLabels || reservesWeight {
            Text(title)
                .font(.body.weight(.semibold))
                .hidden()
                .overlay { label }
        } else {
            label
        }
    }

    /// Whether the segment at `index` shows its hint now.
    func showsHint(at index: Int) -> Bool {
        !hintsOnDemand || showsHints || pointerIndex == index
    }

    func segmentLabel(
        _ title: String,
        hint: String?,
        selected: Bool,
        index: Int
    ) -> some View {
        HStack(spacing: 5) {
            if hintsOnDemand, let hint {
                let shown = showsHint(at: index)
                // The wider of the two holds the width either way.
                ZStack {
                    titleText(title, selected: selected, index: index)
                        .opacity(shown ? 0 : 1)
                    hintText(
                        hint,
                        selected: selected,
                        hovered: hoveredIndex == index
                    )
                    .opacity(shown ? 1 : 0)
                }
                .animation(
                    reduceMotion ? nil : .easeOut(duration: 0.12),
                    value: shown
                )
            } else {
                titleText(title, selected: selected, index: index)
                if let hint {
                    hintText(
                        hint,
                        selected: selected,
                        hovered: hoveredIndex == index
                    )
                }
            }
        }
        .lineLimit(1)
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background(
            Capsule().fill(
                isEnabled && !selected && hoveredIndex == index
                    ? paint.fill(paint.rowHover) : AnyShapeStyle(.clear)
            )
        )
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.12),
            value: hoveredIndex
        )
        .contentShape(Capsule())
    }

    private func titleText(
        _ title: String,
        selected: Bool,
        index: Int
    ) -> some View {
        labelText(title, selected: selected)
            .foregroundStyle(
                selected && !neutral
                    ? AnyShapeStyle(paint.selectionInk) : restInk(index)
            )
    }

    /// The selected segment's ink is one value, measured on each
    /// mode's fill; the hover lift takes full ink, `ink2`
    /// falling under 4.5:1 on it in dark.
    func hintText(
        _ hint: String,
        selected: Bool,
        hovered: Bool
    ) -> some View {
        Text(hint)
            .font(.callout)
            .foregroundStyle(
                selected
                    ? AnyShapeStyle(paint.selectionInkSecondary)
                    : paint.tinted
                        ? hovered
                            ? AnyShapeStyle(paint.hoverInk ?? .primary)
                            : AnyShapeStyle(.secondary)
                        : AnyShapeStyle(
                            hovered ? SettingsTheme.ink : SettingsTheme.ink2
                        )
            )
            .accessibilityHidden(true)
    }
}
