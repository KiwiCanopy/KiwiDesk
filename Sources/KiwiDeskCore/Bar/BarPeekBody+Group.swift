import AppKit

/// A peek group's views before placement, and its header's
/// placement (#1946, #2649).
extension BarPeekBody {
    /// One group's views before placement.
    struct Built {
        let group: BarPeekContent.Group
        /// The icon the header draws: the app's on a full header.
        let icon: NSImage?
        /// Nil where the group draws no header (#2649).
        let header: NSTextField?
        let rows: [NSTextField]
        /// Each row's Pocket key, where it draws one (#2923).
        let chords: [NSTextField?]

        /// The width it reads at on one line each.
        @MainActor
        func need(indent: CGFloat) -> CGFloat {
            let iconPart = icon == nil ? 0 : indent
            let name = header.map { BarPeekBody.natural($0) } ?? 0
            let row =
                zip(rows, chords).map { title, chord in
                    BarPeekBody.natural(title)
                        + (chord.map { BarPeekBody.chordRoom($0) } ?? 0)
                }.max() ?? 0
            return max(iconPart + name, indent + row)
        }
    }

    /// Places a group's header and its icon from `top`; returns
    /// where its rows start.
    func placeHeader(
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
            add(icon: icon)
        }
        let gap = built.rows.isEmpty ? 0 : Metrics.headerGap
        return top + max(nameHeight, line) + gap
    }
}
