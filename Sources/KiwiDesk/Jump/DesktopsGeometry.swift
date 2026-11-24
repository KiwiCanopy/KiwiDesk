import CoreGraphics
import KiwiDeskCore

/// The Desktops side's sizes, derived from the desk and the panel
/// (#3164, #3570 ruling 4): each screen is a column in physical
/// order, its Desktops stacked downward. One line height for every
/// column, the largest from 36 down to 30 pt at which the tallest
/// column stands whole under the cap; the columns share the panel's
/// width, never narrower than 224 pt, past which the row of screens
/// scrolls sideways; a line's icon slots follow its column's width.
/// On a split screen each Desktop counts an area header and its gap
/// per area (#3572). Pure, so the side and the state read one
/// answer.
struct DesktopsGeometry: Equatable {
    static let tallestLine: CGFloat = 36
    static let shortestLine: CGFloat = 30
    static let narrowestColumn: CGFloat = 224
    /// A screen column's header line and a Desktop's title line.
    static let headerHeight: CGFloat = 22
    static let titleHeight: CGFloat = 22
    /// An area group's header on a split screen (#3572 ruling 2).
    static let areaHeight: CGFloat = 16
    /// The side's own padding above and below its columns.
    static let sidePadding: CGFloat = 8
    /// Between a column's header and its first Desktop, between
    /// two Desktops, between a title and its lines, and between an
    /// area header and its lines.
    static let headerGap: CGFloat = 4
    static let desktopGap: CGFloat = 8
    static let titleGap: CGFloat = 2
    static let areaGap: CGFloat = 2
    /// A column's inner margin on each side, and the divider
    /// between two columns.
    static let columnInset: CGFloat = 6
    static let divider = KiwiHubPaint.hairline
    /// The columns' margin inside the panel on each side: the
    /// selection inset plus the header's own indent.
    static let rowInset: CGFloat = KeyPanelStyle.selectionInset + 10
    /// A line's horizontal padding, its Space name's least width
    /// and the two "+n" counts, which icon slots never take; the
    /// line's own spacing between those comes out of the name's.
    static let linePadding: CGFloat = 4
    static let labelReserve: CGFloat = 64
    static let moreReserve: CGFloat = 32
    static let iconGap: CGFloat = 2

    /// Every Space line's height.
    let line: CGFloat
    /// Each screen column's width, in overview order.
    let columns: [CGFloat]
    /// The height each screen column's Desktops take below its
    /// header, whole.
    let stacks: [CGFloat]
    /// The side's height: the tallest column whole up to the cap,
    /// past which the columns scroll down.
    let height: CGFloat

    init(overview: DesktopOverview, width: CGFloat, cap: CGFloat) {
        let screens = overview.screens
        let budget = cap - Self.chrome
        let line = Self.lineHeight(screens, budget: budget)
        self.line = line
        stacks = screens.map { Self.stack($0, line: line) }
        let room = width - 2 * Self.rowInset
        columns = Self.columns(count: screens.count, room: room)
        height = min(Self.chrome + (stacks.max() ?? 0), cap)
    }

    /// The width the side asks of the panel (#3570 ruling 4): one
    /// narrowest column per screen, its dividers and its margins.
    /// The panel grants it up to its limit, past which the row of
    /// screens scrolls sideways.
    static func preferredWidth(of overview: DesktopOverview) -> CGFloat {
        let n = CGFloat(max(overview.screens.count, 1))
        return 2 * rowInset + n * narrowestColumn + (n - 1) * divider
    }

    /// A Space line's icon: the line height less 8, so never under
    /// the Windows rows' 22 pt at the shortest line.
    var icon: CGFloat { line - 8 }

    /// The height of the column scroll below a screen's header.
    var body: CGFloat {
        max(height - Self.chrome, 0)
    }

    /// The icon slots each screen column's lines show at once; more
    /// fold into "+n".
    var slots: [Int] {
        columns.map { column in
            let room =
                column - 2 * Self.columnInset - 2 * Self.linePadding
                - Self.labelReserve - Self.moreReserve
            let slot = icon + Self.iconGap
            return max(Int(((room + Self.iconGap) / slot).rounded(.down)), 1)
        }
    }

    /// The columns of `count` screens sharing `room`.
    static func columns(count: Int, room: CGFloat) -> [CGFloat] {
        guard count > 0 else { return [] }
        let n = CGFloat(count)
        let share = ((room - (n - 1) * divider) / n).rounded(.down)
        return Array(repeating: max(share, narrowestColumn), count: count)
    }

    /// What the side stands besides its columns' Desktops: its
    /// padding and a column's header.
    static var chrome: CGFloat {
        2 * sidePadding + headerHeight + headerGap
    }

    /// The largest line height at which the tallest column fits
    /// `budget`, held between the shortest and the tallest line.
    private static func lineHeight(
        _ screens: [DesktopOverview.Screen],
        budget: CGFloat
    ) -> CGFloat {
        let fits = screens.map { screen -> CGFloat in
            let lines = screen.desktops.map(\.spaces.count).reduce(0, +)
            guard lines > 0 else { return tallestLine }
            let fixed = stack(screen, line: 0)
            return ((budget - fixed) / CGFloat(lines)).rounded(.down)
        }
        let fit = fits.min() ?? tallestLine
        return min(max(fit, shortestLine), tallestLine)
    }

    /// One screen's Desktops stacked at `line` per Space line.
    static func stack(
        _ screen: DesktopOverview.Screen,
        line: CGFloat
    ) -> CGFloat {
        let desktops = screen.desktops.map { card(of: $0, line: line) }
        let gaps = CGFloat(max(desktops.count - 1, 0)) * desktopGap
        return desktops.reduce(0, +) + gaps
    }

    /// One Desktop's card: its title, its lines and, on a split
    /// screen, a header and its gap per area.
    static func card(
        of desktop: DesktopOverview.Desktop,
        line: CGFloat
    ) -> CGFloat {
        let areas = CGFloat(desktop.areas.count) * (areaHeight + areaGap)
        return titleHeight + titleGap + areas
            + CGFloat(desktop.spaces.count) * line
    }
}
