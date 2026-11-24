import CoreGraphics
import KiwiDeskCore

/// The shared-Desktop grid's sizes (#3602): one row per Desktop
/// under the screens' headers, a header column on the left. A row
/// stands as tall as its header or its tallest cell, whichever is
/// taller, with `rowPadding` above and below and a hairline between
/// two rows; the line height is the tallest from 36 down to 30 pt
/// at which every row stands whole under the cap.
extension DesktopsGeometry {
    /// The header column's width bounds, and its gap to the first
    /// screen's column.
    static let narrowestGutter: CGFloat = 96
    static let widestGutter: CGFloat = 132
    static let gutterGap: CGFloat = 8
    /// A row header's profile line, below its title.
    static let profileHeight: CGFloat = 16
    /// The ✓ and its gap after a header's title, and the header's
    /// insets: the leading one clear of the row's hover ring.
    static let checkSlot: CGFloat = 18
    static let headerLeading: CGFloat = 8
    static let headerTrailing: CGFloat = 2
    /// Above and below a row's cells.
    static let rowPadding: CGFloat = 4

    /// The grid's header column and its rows' heights.
    struct Grid: Equatable {
        let gutter: CGFloat
        let rows: [CGFloat]

        /// The rows stacked, a hairline between two.
        var height: CGFloat {
            rows.reduce(0, +) + CGFloat(max(rows.count - 1, 0)) * divider
        }
    }

    /// The header column's width: the widest title `measure` draws,
    /// the ✓ and the insets, held to 96–132 pt; nil without rows.
    /// Main actor for the titles' localized text.
    @MainActor
    static func gutter(
        of overview: DesktopOverview,
        measure: (String) -> CGFloat = DesktopsGutter.titleWidth
    ) -> CGFloat? {
        guard !overview.rows.isEmpty, let first = overview.screens.first
        else { return nil }
        let widest =
            first.desktops.map {
                measure(DesktopsText.desktop($0.label))
            }.max() ?? 0
        let width = (widest + checkSlot + headerLeading + headerTrailing)
            .rounded(.up)
        return min(max(width, narrowestGutter), widestGutter)
    }

    /// Every row's height at `line` per Space line.
    static func rows(
        of overview: DesktopOverview,
        line: CGFloat
    ) -> [CGFloat] {
        overview.rows.indices.map { row($0, of: overview, line: line) }
    }

    /// Row `index`: its header or its tallest cell, padded.
    static func row(
        _ index: Int,
        of overview: DesktopOverview,
        line: CGFloat
    ) -> CGFloat {
        let desktops = overview.screens.compactMap {
            $0.desktops.indices.contains(index) ? $0.desktops[index] : nil
        }
        let cells = desktops.map { cell(of: $0, line: line) }.max() ?? 0
        let profile = desktops.first?.profile != nil
        return max(header(line: line, profile: profile), cells)
            + 2 * rowPadding
    }

    /// A row header's height: its title centred on the first line,
    /// and the profile line under it where one is bound.
    static func header(line: CGFloat, profile: Bool) -> CGFloat {
        titleTop(line: line) + titleHeight + (profile ? profileHeight : 0)
    }

    /// How far a row header's title sits below the row's cells' top,
    /// centring it on a first line `line` tall.
    static func titleTop(line: CGFloat) -> CGFloat {
        max(((line - titleHeight) / 2).rounded(.down), 0)
    }

    /// The largest line height at which every row fits `budget`.
    static func gridLineHeight(
        _ overview: DesktopOverview,
        budget: CGFloat
    ) -> CGFloat {
        var line = tallestLine
        while line > shortestLine,
            Grid(gutter: 0, rows: rows(of: overview, line: line)).height
                > budget
        {
            line -= 1
        }
        return line
    }

    /// Where line `index` of `desktop` starts below its cell's top:
    /// the area headers above it and the lines before it.
    static func lineTop(
        of desktop: DesktopOverview.Desktop,
        at index: Int,
        line: CGFloat
    ) -> CGFloat {
        let headers = desktop.areas.filter { $0.lines.lowerBound <= index }
        return CGFloat(headers.count) * (areaHeight + areaGap)
            + CGFloat(index) * line
    }
}
