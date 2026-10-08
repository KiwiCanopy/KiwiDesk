import AppKit

/// The peek's text (#1946, the owner's rulings): each group's
/// header — the app, smaller and semibold in the item ink, its icon
/// on `+n`, its count pill from two windows — above one wrapped
/// row per window, hairlines between, each row its window's button
/// (`BarPeekBody+Targets`). Rebuilt on every show, so nothing it
/// draws outlives the content Core read.
@MainActor
final class BarPeekBody: NSView {
    /// The peek's geometry and reading sizes, one home.
    enum Metrics {
        /// A fixed reading size, never the strip-depth ladders, or
        /// a thin bar's peek turns unreadable (#1946).
        static let textSize: CGFloat = 13
        /// The header's size: the menus' section header.
        static let headerSize: CGFloat = 11
        static let countSize: CGFloat = 11.5
        static let pillHeight: CGFloat = 18
        static let pillPad: CGFloat = 6
        /// `macwindow`'s ink height per point at `.regular`, measured
        /// on macOS 27 (0.89–0.90 at 100–200 pt): the glyph's size
        /// is the count's cap height over this (#1946).
        static let pillGlyphInkPerPoint: CGFloat = 0.9
        /// The window glyph's gap to the count.
        static let pillGlyphGap: CGFloat = 3
        /// The pill's ring, in the hairlines' ink.
        static let pillRing: CGFloat = 1
        /// The whole panel's widest; a title wraps inside it.
        static let maxWidth: CGFloat = 280
        static let padH: CGFloat = 12
        static let padV: CGFloat = 9
        static let headerGap: CGFloat = 4
        /// Space either side of a hairline between two windows.
        static let rowGap: CGFloat = 5
        /// Space either side of a hairline between two apps.
        static let groupGap: CGFloat = 8
        static let iconSide: CGFloat = 16
        static let iconGap: CGFloat = 5
        /// The "more" line's chevron.
        static let chevronSide: CGFloat = 12
        static let pillGap: CGFloat = 8
        static let cornerRadius: CGFloat = 11
        /// The gap between the bar's panel and the peek.
        static let stripGap: CGFloat = 6
        static let screenMargin: CGFloat = 8
        /// How far a button's hover fill reaches past its text.
        static let hoverPadH: CGFloat = 6
        static let hoverPadV: CGFloat = 3
        static let hoverRadius: CGFloat = 6
    }

    override var isFlipped: Bool { true }

    /// What the last build drew, top to bottom: headers and
    /// titles, the count pills, the icons and the hairlines.
    private(set) var labels: [NSTextField] = []
    private(set) var pills: [BarPeekPill] = []
    private(set) var icons: [NSImageView] = []
    var rules: [NSView] = []
    /// The "more" line's count and chevron, where the room cut
    /// the list (`BarPeekBody+More`).
    var moreLabel: NSTextField?
    var moreChevron: NSImageView?
    /// The hairlines' ink: the bar's rule tier (`BarDivider`).
    private(set) var ruleInk = NSColor.clear
    /// The buttons the last build laid out, top to bottom, and the
    /// shelf whose inks they wear (`BarPeekBody+Targets`).
    var targets: [Target] = []
    var shelf = KiwiShelf()
    /// The button under the pointer, and the one a press took.
    var hovered: Int?
    var pressed: Int?
    /// The one fill drawn under the hovered button.
    let highlight = NSView()
    /// A row's window picked, or "N more" pressed — the peek's.
    var onPick: @MainActor (WindowID) -> Void = { _ in }
    var onMore: @MainActor () -> Void = {}
    /// The pointer entered (true) or left the body — its own
    /// tracking, so a held peek polls only the gap (#1946).
    var onPointerInside: @MainActor (Bool) -> Void = { _ in }

    /// Lays `content` out in `shelf`'s face and ink, with a "more"
    /// line where `hidden` windows did not fit — above the list
    /// when `cutAtTop`, else below it; returns the panel's size.
    func layout(
        _ content: BarPeekContent,
        shelf: KiwiShelf,
        hidden: Int,
        cutAtTop: Bool = false
    ) -> CGSize {
        subviews.forEach { $0.removeFromSuperview() }
        labels = []
        pills = []
        icons = []
        rules = []
        moreLabel = nil
        moreChevron = nil
        resetTargets(shelf)
        setAccessibilityElement(false)
        ruleInk = BarDivider.color(textColor: shelf.itemColor)
        let ink = NSColor(kiwiHex: shelf.itemColor)
        let headerInk = NSColor(kiwiHex: shelf.peekHeaderColor)
        let textFont = shelf.textFont(ofSize: Metrics.textSize)
        let headerFont = shelf.textFont(
            ofSize: Metrics.headerSize,
            emphasis: .semibold
        )
        let groups = content.groups.map { group in
            Built(
                group: group,
                // A derived step under the titles, full ink where
                // the palette cannot hold it (owner ruling, #1946).
                header: Self.label(group.app, headerFont, headerInk),
                rows: group.titles.map { Self.label($0, textFont, ink) },
                pill: group.count.map { pill($0, shelf: shelf) }
            )
        }
        // Icons mark mixed apps (`+n`); their rows sit under the
        // name.
        let indent =
            content.groups.contains { $0.icon != nil }
            ? Metrics.iconSide + Metrics.iconGap : 0
        let more =
            hidden > 0
            ? moreLine(hidden, shelf: shelf, up: cutAtTop) : nil
        let width = min(
            Metrics.maxWidth - 2 * Metrics.padH,
            max(
                groups.map { $0.need(indent: indent) }.max() ?? 0,
                more?.width ?? 0
            )
        )
        var y = Metrics.padV
        if let more, cutAtTop {
            y = place(more, at: y, width: width) + Metrics.rowGap
        }
        for (index, built) in groups.enumerated() {
            if index > 0 {
                addRule(at: y + Metrics.groupGap, x: 0, width: width)
                y += 2 * Metrics.groupGap + BarDivider.ruleThickness
            }
            y = place(built, at: y, width: width, indent: indent)
        }
        if let more, !cutAtTop {
            y = place(more, at: y + Metrics.rowGap, width: width)
        }
        let size = CGSize(
            width: ceil(width + 2 * Metrics.padH),
            height: ceil(y + Metrics.padV)
        )
        frame.size = size
        return size
    }

    /// One group's views before placement.
    private struct Built {
        let group: BarPeekContent.Group
        let header: NSTextField
        let rows: [NSTextField]
        let pill: BarPeekPill?

        /// The width it reads at on one line each.
        @MainActor
        func need(indent: CGFloat) -> CGFloat {
            let pillPart =
                pill.map { $0.frame.width + Metrics.pillGap } ?? 0
            let iconPart = group.icon == nil ? 0 : indent
            let name = BarPeekBody.natural(header)
            let row = rows.map { BarPeekBody.natural($0) }.max() ?? 0
            return max(iconPart + name + pillPart, indent + row)
        }
    }

    /// Places `built` from `top`; returns where it ends.
    private func place(
        _ built: Built,
        at top: CGFloat,
        width: CGFloat,
        indent: CGFloat
    ) -> CGFloat {
        let lead = Metrics.padH
        let iconPart = built.group.icon == nil ? 0 : indent
        let pillPart =
            built.pill.map { $0.frame.width + Metrics.pillGap } ?? 0
        let nameWidth = max(width - iconPart - pillPart, 1)
        let nameHeight = Self.height(of: built.header, width: nameWidth)
        built.header.frame = CGRect(
            x: lead + iconPart,
            y: top,
            width: nameWidth,
            height: nameHeight
        )
        add(built.header)
        // The icon and the pill sit on the header's first line.
        let line = Self.lineHeight(built.header.font)
        if let image = built.group.icon {
            let icon = NSImageView(image: image)
            icon.imageScaling = .scaleProportionallyUpOrDown
            icon.setAccessibilityElement(false)
            icon.frame = CGRect(
                x: lead,
                y: top + (line - Metrics.iconSide) / 2,
                width: Metrics.iconSide,
                height: Metrics.iconSide
            )
            addSubview(icon)
            icons.append(icon)
        }
        if let pill = built.pill {
            pill.frame.origin = CGPoint(
                x: lead + width - pill.frame.width,
                y: top + (line - Metrics.pillHeight) / 2
            )
            addSubview(pill)
            pills.append(pill)
        }
        let gap = built.rows.isEmpty ? 0 : Metrics.headerGap
        var y = top + max(nameHeight, line) + gap
        let rowWidth = max(width - indent, 1)
        for (index, row) in built.rows.enumerated() {
            if index > 0 {
                addRule(at: y + Metrics.rowGap, x: indent, width: rowWidth)
                y += 2 * Metrics.rowGap + BarDivider.ruleThickness
            }
            let height = Self.height(of: row, width: rowWidth)
            row.frame = CGRect(
                x: lead + indent,
                y: y,
                width: rowWidth,
                height: height
            )
            add(row)
            addTarget(
                .window(built.group.rows[index].window),
                around: row.frame,
                inks: [row]
            )
            y += height
        }
        return y
    }

    private func add(_ label: NSTextField) {
        addSubview(label)
        labels.append(label)
    }
}
