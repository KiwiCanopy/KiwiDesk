import SwiftUI

/// A left-aligned layout that flows subviews across the available
/// width and wraps to the next line when the current one is full.
/// Used for chip palettes (e.g. draggable spaces) where a fixed
/// grid would waste space.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        let width = proposal.width ?? .infinity
        return arrange(subviews, in: width).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let rows = arrange(subviews, in: bounds.width).rows
        for row in rows {
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(
                        x: bounds.minX + item.x,
                        y: bounds.minY + row.y
                    ),
                    proposal: ProposedViewSize(item.size)
                )
            }
        }
    }

    // MARK: - Arrangement

    private struct Item {
        let index: Int
        let x: CGFloat
        let size: CGSize
    }
    private struct Row {
        var y: CGFloat = 0
        var items: [Item] = []
    }

    private func arrange(
        _ subviews: Subviews,
        in maxWidth: CGFloat
    ) -> (size: CGSize, rows: [Row]) {
        var rows: [Row] = []
        var current = Row()
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                current.y = totalHeight
                rows.append(current)
                totalHeight += rowHeight + spacing
                maxRowWidth = max(maxRowWidth, x - spacing)
                current = Row()
                x = 0
                rowHeight = 0
            }
            current.items.append(
                Item(index: index, x: x, size: size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        current.y = totalHeight
        rows.append(current)
        maxRowWidth = max(maxRowWidth, x - spacing)
        totalHeight += rowHeight

        return (
            CGSize(
                width: max(0, maxRowWidth),
                height: totalHeight
            ), rows
        )
    }
}
