import CoreGraphics

/// Niri/PaperWM-style scrolling columns.
///
/// Windows sit in an infinite row (horizontal orientation) or
/// column (vertical) of fixed-size slots; the viewport shifts so
/// the focused slot lands at the configured anchor. Slots at the
/// ends snap to the screen edge so no empty margin appears. With
/// the indicator bar enabled its strip is carved out of the
/// usable area first, so windows and bar never overlap.
public struct ScrollingLayout: LayoutSystem {
    public init() {}

    public func calculateGeometry(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [WindowID: CGRect] {
        guard !windows.isEmpty else { return [:] }

        // The area left for windows after the bar strip.
        let area = context.scrolling.windowFrame(
            in: context.usable,
            inner: context.gaps.inner,
            global: context.appBarStyle
        )
        let horizontal = context.scrolling.barAxisIsHorizontal

        // A single window always fills the whole window area.
        if windows.count == 1, let only = windows.first {
            return [only: area]
        }

        let gap =
            horizontal
            ? context.gaps.inner.horizontal
            : context.gaps.inner.vertical
        let along = horizontal ? area.width : area.height
        let size = context.scrolling.slotSize.resolved(
            along: along,
            horizontal: horizontal
        )
        let stride = size + gap
        let count = CGFloat(windows.count)
        let rowLength = count * size + (count - 1) * gap

        let focusedIndex =
            context.focused.flatMap {
                windows.firstIndex(of: $0)
            } ?? 0
        let focusedPos = CGFloat(focusedIndex) * stride
        var offset = anchorOffset(
            anchor: context.scrolling.anchor,
            along: along,
            size: size,
            focusedPos: focusedPos
        )

        // Boundary awareness: snap to the row ends.
        if rowLength <= along {
            offset = 0
        } else {
            offset = min(offset, 0)
            offset = max(offset, along - rowLength)
        }

        return frames(
            windows: windows,
            area: area,
            horizontal: horizontal,
            offset: offset,
            stride: stride,
            size: size
        )
    }

    /// Offset of the row start relative to the area's leading
    /// edge, before boundary snapping.
    private func anchorOffset(
        anchor: ScrollingParams.Anchor,
        along: CGFloat,
        size: CGFloat,
        focusedPos: CGFloat
    ) -> CGFloat {
        switch anchor {
        case .center:
            return (along - size) / 2 - focusedPos
        case .left:
            return -focusedPos
        case .right:
            return along - size - focusedPos
        }
    }

    private func frames(
        windows: [WindowID],
        area: CGRect,
        horizontal: Bool,
        offset: CGFloat,
        stride: CGFloat,
        size: CGFloat
    ) -> [WindowID: CGRect] {
        var result: [WindowID: CGRect] = [:]
        for (index, window) in windows.enumerated() {
            let lead = offset + CGFloat(index) * stride
            result[window] =
                horizontal
                ? CGRect(
                    x: area.minX + lead,
                    y: area.minY,
                    width: size,
                    height: area.height
                )
                : CGRect(
                    x: area.minX,
                    y: area.minY + lead,
                    width: area.width,
                    height: size
                )
        }
        return result
    }
}
