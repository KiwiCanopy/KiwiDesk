import CoreGraphics

/// Niri/PaperWM-style horizontal scrolling columns.
///
/// Windows sit side by side in an infinite row of fixed-width
/// columns; the viewport shifts so the focused column lands at
/// the configured anchor. Columns at the row ends snap to the
/// screen edge so no empty margin appears.
public struct ScrollingLayout: LayoutSystem {
    public init() {}

    public func calculateGeometry(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [WindowID: CGRect] {
        let usable = context.usable
        guard !windows.isEmpty else { return [:] }

        // A single window always fills the whole screen.
        if windows.count == 1, let only = windows.first {
            return [only: usable]
        }

        let gap = context.gaps.inner.horizontal
        let width = min(
            context.scrolling.windowWidth,
            usable.width
        )
        let stride = width + gap
        let count = CGFloat(windows.count)
        let rowWidth = count * width + (count - 1) * gap

        let focusedIndex =
            context.focused.flatMap {
                windows.firstIndex(of: $0)
            } ?? 0
        let focusedX = CGFloat(focusedIndex) * stride

        // Offset of the row start relative to usable.minX.
        var offset: CGFloat
        switch context.scrolling.anchor {
        case .center:
            offset =
                (usable.width - width) / 2 - focusedX
        case .left:
            offset = -focusedX
        case .right:
            offset = usable.width - width - focusedX
        }

        // Boundary awareness: snap to the row ends.
        if rowWidth <= usable.width {
            offset = 0
        } else {
            offset = min(offset, 0)
            offset = max(offset, usable.width - rowWidth)
        }

        var result: [WindowID: CGRect] = [:]
        for (index, window) in windows.enumerated() {
            let x =
                usable.minX + offset
                + CGFloat(index) * stride
            result[window] = CGRect(
                x: x,
                y: usable.minY,
                width: width,
                height: usable.height
            )
        }
        return result
    }
}
