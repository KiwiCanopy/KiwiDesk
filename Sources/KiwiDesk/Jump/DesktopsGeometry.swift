import CoreGraphics
import KiwiDeskCore

/// The Desktops side's sizes, derived from the desk and the panel
/// (#3164 ▸ Ruling and amendment): one line height for every
/// column, the largest from 36 down to 30 pt at which every screen
/// row stands whole under the cap; each screen row's columns share
/// its width, never narrower than 224 pt; a line's icon slots
/// follow its width. Pure, so the side and the state read one
/// answer.
struct DesktopsGeometry: Equatable {
    static let tallestLine: CGFloat = 36
    static let shortestLine: CGFloat = 30
    static let narrowestColumn: CGFloat = 224
    /// A screen row's header line and a column's title line.
    static let headerHeight: CGFloat = 22
    static let titleHeight: CGFloat = 22
    /// The side's own padding above and below its rows, and the
    /// gap between two rows.
    static let sidePadding: CGFloat = 8
    static let rowGap: CGFloat = 8
    /// Between a row's header and its columns, and between a
    /// column's title and its lines.
    static let headerGap: CGFloat = 4
    static let titleGap: CGFloat = 2
    /// A column's inner margin on each side, and the divider
    /// between two columns.
    static let columnInset: CGFloat = 6
    static let divider: CGFloat = 1
    /// The rows' margin inside the panel on each side: the
    /// selection inset plus the header's own indent.
    static let rowInset: CGFloat = KeyPanelStyle.selectionInset + 10
    /// A line's horizontal padding, its Space name's least width
    /// and the two "+n" counts, which icon slots never take.
    static let linePadding: CGFloat = 4
    static let labelReserve: CGFloat = 64
    static let moreReserve: CGFloat = 32
    static let iconGap: CGFloat = 2

    /// Every Space line's height.
    let line: CGFloat
    /// Each screen row's line area: every line of its deepest
    /// Desktop where they fit, else the cap's share, which scrolls.
    let lines: [CGFloat]
    /// Each screen row's column width, in overview order.
    let columns: [CGFloat]
    /// The side's height: every row whole up to the cap, past which
    /// it scrolls.
    let height: CGFloat

    init(overview: DesktopOverview, width: CGFloat, cap: CGFloat) {
        let screens = overview.screens
        let most =
            screens.flatMap(\.desktops).map(\.spaces.count).max() ?? 0
        // Past two screens the side scrolls, so two rows set the fit.
        let fitted = CGFloat(min(max(screens.count, 1), 2))
        let budget = (cap - Self.chrome(rows: fitted)) / fitted
        let fit = most > 0 ? (budget / CGFloat(most)).rounded(.down) : 0
        let line = min(max(fit, Self.shortestLine), Self.tallestLine)
        let share = max(budget, line)
        self.line = line
        lines = screens.map { screen in
            let deepest = screen.desktops.map(\.spaces.count).max() ?? 0
            return min(CGFloat(deepest) * line, share)
        }
        let room = width - 2 * Self.rowInset
        columns = screens.map {
            Self.column(count: $0.desktops.count, room: room)
        }
        let rows = CGFloat(screens.count)
        height = min(Self.chrome(rows: rows) + lines.reduce(0, +), cap)
    }

    /// A Space line's icon: the line height less 8, never under the
    /// Windows rows' 22 pt.
    var icon: CGFloat { max(line - 8, 22) }

    /// One screen row's height: its header, a column's title and
    /// its lines.
    func rowHeight(_ screen: Int) -> CGFloat {
        Self.rowChrome + lines[screen]
    }

    /// The icon slots each screen row's lines show at once; more
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

    /// A column's width in a row of `count` Desktops sharing `room`.
    static func column(count: Int, room: CGFloat) -> CGFloat {
        guard count > 0 else { return narrowestColumn }
        let n = CGFloat(count)
        let share = (room - (n - 1) * divider) / n
        return max(share.rounded(.down), narrowestColumn)
    }

    /// What one screen row stands besides its lines.
    static var rowChrome: CGFloat {
        headerHeight + headerGap + titleHeight + titleGap
    }

    /// What `rows` screen rows stand besides their lines.
    static func chrome(rows: CGFloat) -> CGFloat {
        2 * sidePadding + max(rows - 1, 0) * rowGap + rows * rowChrome
    }
}
