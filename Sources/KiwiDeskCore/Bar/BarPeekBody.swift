import AppKit

/// The peek's text (#1946, the owner's ruling): each group's
/// header — the app, smaller and semibold in the item ink, its icon
/// on `+n`, its count pill from two windows — above one wrapped
/// row per window, hairlines between. Rebuilt on every show, so
/// nothing it draws outlives the content Core read.
@MainActor
final class BarPeekBody: NSView {
    /// The peek's geometry and reading sizes, one home.
    enum Metrics {
        /// A fixed reading size, never the strip-depth ladders, or
        /// a thin bar's peek turns unreadable (#1946).
        static let textSize: CGFloat = 13
        /// The header's size: the menus' section header.
        static let headerSize: CGFloat = 11
        static let countSize: CGFloat = 10
        static let pillHeight: CGFloat = 16
        static let pillPad: CGFloat = 4
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
        static let pillGap: CGFloat = 8
        static let cornerRadius: CGFloat = 11
        /// The gap between the bar's panel and the peek.
        static let stripGap: CGFloat = 6
        static let screenMargin: CGFloat = 8
    }

    override var isFlipped: Bool { true }

    /// What the last build drew, top to bottom: headers and
    /// titles, the count pills, the icons and the hairlines.
    private(set) var labels: [NSTextField] = []
    private(set) var pills: [NSTextField] = []
    private(set) var icons: [NSImageView] = []
    var rules: [NSView] = []
    /// The hairlines' ink: the bar's rule tier (`BarDivider`).
    private(set) var ruleInk = NSColor.clear

    /// Lays `content` out in `shelf`'s face and ink; returns the
    /// panel's size.
    func build(_ content: BarPeekContent, shelf: KiwiShelf) -> CGSize {
        subviews.forEach { $0.removeFromSuperview() }
        labels = []
        pills = []
        icons = []
        rules = []
        setAccessibilityElement(false)
        ruleInk = BarDivider.color(textColor: shelf.itemColor)
        let ink = NSColor(kiwiHex: shelf.itemColor)
        let textFont = shelf.textFont(ofSize: Metrics.textSize)
        let headerFont = shelf.textFont(
            ofSize: Metrics.headerSize,
            emphasis: .semibold
        )
        let groups = content.groups.map { group in
            Built(
                group: group,
                // Full ink: weight and size carry the hierarchy,
                // and a dimmed ink's legibility rides on a palette
                // nobody can pre-check (owner ruling on #1946).
                header: Self.label(group.app, headerFont, ink),
                rows: group.titles.map { Self.label($0, textFont, ink) },
                pill: group.count.map { pill($0, shelf: shelf) }
            )
        }
        // Icons mark mixed apps (`+n`); their rows sit under the
        // name.
        let indent =
            content.groups.contains { $0.icon != nil }
            ? Metrics.iconSide + Metrics.iconGap : 0
        let width = min(
            Metrics.maxWidth - 2 * Metrics.padH,
            groups.map { $0.need(indent: indent) }.max() ?? 0
        )
        var y = Metrics.padV
        for (index, built) in groups.enumerated() {
            if index > 0 {
                addRule(at: y + Metrics.groupGap, x: 0, width: width)
                y += 2 * Metrics.groupGap + BarDivider.ruleThickness
            }
            y = place(built, at: y, width: width, indent: indent)
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
        let pill: NSTextField?

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
        var y = top + max(nameHeight, line) + Metrics.headerGap
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
            y += height
        }
        return y
    }

    private func add(_ label: NSTextField) {
        addSubview(label)
        labels.append(label)
    }
}
