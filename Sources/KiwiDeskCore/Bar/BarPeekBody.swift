import AppKit

/// The peek's text (#1946, the owner's rulings): each group's
/// header — the app, smaller and semibold in the item ink, its icon
/// on a list; what it draws is the content's `header` (#2649) —
/// above one wrapped
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
        static let cornerRadius: CGFloat = 11
        /// The gap between the bar's panel and the peek.
        static let stripGap: CGFloat = 6
        static let screenMargin: CGFloat = 8
        /// How far a button's hover fill reaches past its text.
        static let hoverPadH: CGFloat = 6
        static let hoverPadV: CGFloat = 3
        static let hoverRadius: CGFloat = 6
        /// The focused row's check (#2063), and its column past the
        /// titles' wrap width: the check plus a gap before it.
        static let checkSide: CGFloat = 12
        static let checkColumn: CGFloat = 16
    }

    override var isFlipped: Bool { true }

    /// Room a grown list keeps for its header strip (#2563): above
    /// or below the rows, and the pill's width at least.
    struct Reserve: Equatable {
        var top: CGFloat = 0
        var bottom: CGFloat = 0
        var minWidth: CGFloat = 0
        static let none = Reserve()
    }
    var reserve = Reserve.none

    /// What the last build drew, top to bottom: headers and
    /// titles, the icons and the hairlines.
    private(set) var labels: [NSTextField] = []
    private(set) var icons: [NSImageView] = []
    var rules: [NSView] = []
    /// The "more" line's count and chevron, where the room cut
    /// the list (`BarPeekBody+More`).
    var moreLabel: NSTextField?
    var moreChevron: NSImageView?
    /// The focused row's check, where a list's last build drew one.
    var check: NSImageView?
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
        icons = []
        rules = []
        moreLabel = nil
        moreChevron = nil
        check = nil
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
                icon: content.header == .full ? group.icon : nil,
                // A derived step under the titles, full ink where
                // the palette cannot hold it (owner ruling, #1946).
                header: content.header == .none
                    ? nil : Self.label(group.app, headerFont, headerInk),
                rows: group.titles.map { Self.label($0, textFont, ink) }
            )
        }
        // Icons mark mixed apps (`+n`); their rows sit under the
        // name.
        let indent =
            groups.contains { $0.icon != nil }
            ? Metrics.iconSide + Metrics.iconGap : 0
        let more =
            hidden > 0
            ? moreLine(hidden, shelf: shelf, up: cutAtTop) : nil
        let fitted = min(
            Metrics.maxWidth - 2 * Metrics.padH,
            max(
                groups.map { $0.need(indent: indent) }.max() ?? 0,
                more?.width ?? 0
            )
        )
        // A list's check column sits past the wrap width, so titles
        // wrap where they would without it (#2063).
        let column = content.checks ? Metrics.checkColumn : 0
        let width = max(
            fitted,
            reserve.minWidth - column - 2 * Metrics.padH
        )
        var y = Metrics.padV + reserve.top
        if let more, cutAtTop {
            y = place(more, at: y, width: width) + Metrics.rowGap
        }
        for (index, built) in groups.enumerated() {
            if index > 0 {
                addRule(
                    at: y + Metrics.groupGap,
                    x: 0,
                    width: width + column
                )
                y += 2 * Metrics.groupGap + BarDivider.ruleThickness
            }
            y = place(
                built,
                at: y,
                width: width,
                indent: indent,
                column: column
            )
        }
        if let more, !cutAtTop {
            y = place(more, at: y + Metrics.rowGap, width: width)
        }
        let size = CGSize(
            width: ceil(width + column + 2 * Metrics.padH),
            height: ceil(y + Metrics.padV + reserve.bottom)
        )
        frame.size = size
        return size
    }

    /// One group's views before placement.
    private struct Built {
        let group: BarPeekContent.Group
        /// The icon the header draws: the app's on a full header.
        let icon: NSImage?
        /// Nil where the group draws no header (#2649).
        let header: NSTextField?
        let rows: [NSTextField]

        /// The width it reads at on one line each.
        @MainActor
        func need(indent: CGFloat) -> CGFloat {
            let iconPart = icon == nil ? 0 : indent
            let name = header.map { BarPeekBody.natural($0) } ?? 0
            let row = rows.map { BarPeekBody.natural($0) }.max() ?? 0
            return max(iconPart + name, indent + row)
        }
    }

    /// Places `built` from `top`, `column` the check's past
    /// `width`; returns where it ends.
    private func place(
        _ built: Built,
        at top: CGFloat,
        width: CGFloat,
        indent: CGFloat,
        column: CGFloat
    ) -> CGFloat {
        var y = top
        if let header = built.header {
            y = placeHeader(
                header,
                of: built,
                at: top,
                width: width,
                indent: indent
            )
        }
        return placeRows(
            built,
            from: y,
            width: width,
            indent: indent,
            column: column
        )
    }

    /// Places a group's header and its icon from `top`; returns
    /// where its rows start.
    private func placeHeader(
        _ header: NSTextField,
        of built: Built,
        at top: CGFloat,
        width: CGFloat,
        indent: CGFloat
    ) -> CGFloat {
        let lead = Metrics.padH
        let iconPart = built.icon == nil ? 0 : indent
        let nameWidth = max(width - iconPart, 1)
        let nameHeight = Self.height(of: header, width: nameWidth)
        header.frame = CGRect(
            x: lead + iconPart,
            y: top,
            width: nameWidth,
            height: nameHeight
        )
        add(header)
        // The icon sits on the header's first line.
        let line = Self.lineHeight(header.font)
        if let image = built.icon {
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
        let gap = built.rows.isEmpty ? 0 : Metrics.headerGap
        return top + max(nameHeight, line) + gap
    }

    /// Places a group's rows from `top`, `column` the check's past
    /// `width`; returns where they end.
    private func placeRows(
        _ built: Built,
        from top: CGFloat,
        width: CGFloat,
        indent: CGFloat,
        column: CGFloat
    ) -> CGFloat {
        let lead = Metrics.padH
        var y = top
        let rowWidth = max(width - indent, 1)
        for (index, row) in built.rows.enumerated() {
            if index > 0 {
                addRule(
                    at: y + Metrics.rowGap,
                    x: indent,
                    width: rowWidth + column
                )
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
            guard built.group.rows[index].focused, column > 0 else {
                addTarget(
                    .window(built.group.rows[index].window),
                    around: row.frame,
                    inks: [row]
                )
                y += height
                continue
            }
            // Its hover fill reaches over the column, so the check
            // never sits half inside it.
            let mark = addCheck(beside: row, columnEnd: lead + width + column)
            addTarget(
                .window(built.group.rows[index].window),
                around: row.frame.union(mark.frame),
                inks: [row, mark]
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
