import SwiftUI

/// Wrapping flow layout for chips and palettes; each wrapped line
/// is placed by `alignment` within the layout's width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var alignment: HorizontalAlignment = .leading

    /// Where a line `lineWidth` wide starts within `width`.
    static func lineOffset(
        _ lineWidth: CGFloat,
        in width: CGFloat,
        alignment: HorizontalAlignment
    ) -> CGFloat {
        let slack = max(0, width - lineWidth)
        switch alignment {
        case .center: return slack / 2
        case .trailing: return slack
        default: return 0
        }
    }

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
            let lead = Self.lineOffset(
                row.width,
                in: bounds.width,
                alignment: alignment
            )
            for item in row.items {
                // Clamp to the row width so a lone item wider
                // than the bounds truncates instead of spilling
                // past the container's edge.
                subviews[item.index].place(
                    at: CGPoint(
                        x: bounds.minX + lead + item.x,
                        y: bounds.minY + row.y
                    ),
                    proposal: ProposedViewSize(
                        width: min(item.size.width, bounds.width),
                        height: item.size.height
                    )
                )
            }
        }
    }

    private struct Item {
        let index: Int
        let x: CGFloat
        let size: CGSize
    }
    private struct Row {
        var y: CGFloat = 0
        var width: CGFloat = 0
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
                current.width = x - spacing
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
        current.width = max(0, x - spacing)
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
