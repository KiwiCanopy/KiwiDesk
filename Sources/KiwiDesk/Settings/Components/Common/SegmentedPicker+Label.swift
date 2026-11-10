import SwiftUI

/// A segment's drawn label: its title, or its hint in its place.
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

    /// Whether the segment at `index` shows its hint: every one
    /// while `showsAll`, else the one under the pointer.
    static func showsHint(
        showsAll: Bool,
        pointer: Int?,
        index: Int
    ) -> Bool {
        showsAll || pointer == index
    }

    func segmentLabel(
        _ title: String,
        hint: String?,
        selected: Bool,
        index: Int
    ) -> some View {
        let shown =
            hint != nil
            && Self.showsHint(
                showsAll: showsHints,
                pointer: pointerIndex,
                index: index
            )
        // The wider of the two holds the width either way; the
        // clip makes the swap a reel inside the segment.
        return ZStack {
            titleText(title, selected: selected, index: index)
                .modifier(SegmentRoll(hint: false, shown: shown))
            if let hint {
                hintText(
                    hint,
                    selected: selected,
                    hovered: hoveredIndex == index
                )
                .modifier(SegmentRoll(hint: true, shown: shown))
            }
        }
        .coordinateSpace(.named(SegmentRoll.reel))
        .clipped()
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.18),
            value: shown
        )
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

    /// The selected segment's chord takes its title's ink; the
    /// hover lift takes full ink, `ink2` falling under 4.5:1 on it
    /// in dark.
    func hintText(
        _ hint: String,
        selected: Bool,
        hovered: Bool
    ) -> some View {
        Text(hint)
            .font(.callout)
            .foregroundStyle(
                selected && !neutral
                    ? AnyShapeStyle(paint.selectionInk)
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

/// Rolls a segment's label along its reel: the title out downward
/// as the hint drops in from above (#3172).
struct SegmentRoll: ViewModifier {
    nonisolated static let reel = "SegmentRoll.reel"
    let hint: Bool
    let shown: Bool

    /// The vertical offset in points. `reach` is the label's bottom
    /// edge in the reel; a centred label moved by it clears the
    /// reel's bottom, and moved back by it clears the top.
    nonisolated static func offset(
        hint: Bool,
        shown: Bool,
        reach: CGFloat
    ) -> CGFloat {
        hint ? (shown ? 0 : -reach) : (shown ? reach : 0)
    }

    func body(content: Content) -> some View {
        let hint = hint
        let shown = shown
        return content.visualEffect { effect, proxy in
            effect.offset(
                y: Self.offset(
                    hint: hint,
                    shown: shown,
                    reach: proxy.frame(in: .named(Self.reel)).maxY
                )
            )
        }
    }
}
