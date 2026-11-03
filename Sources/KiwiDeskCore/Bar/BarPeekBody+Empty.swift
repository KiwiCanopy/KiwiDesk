import AppKit

/// An empty Pocket's peek (#2941 ▸ Ruling): the header in the item
/// ink, the lines in the secondary ink, a hairline, then the rows
/// landing on Settings, each a button as a window row is. Unlike
/// the window list it speaks to VoiceOver: the header and lines are
/// one text and each row a button, since no menu twins it.
extension BarPeekBody {
    /// Lays `empty` out in `shelf`'s face and ink; returns the size.
    func layout(
        _ empty: BarPeekContent.Empty,
        shelf: KiwiShelf
    ) -> CGSize {
        let ink = NSColor(kiwiHex: shelf.itemColor)
        let quiet = NSColor(kiwiHex: shelf.idleItemColor)
        let font = shelf.textFont(ofSize: Metrics.textSize)
        let title = Self.label(
            empty.title,
            shelf.textFont(ofSize: Metrics.textSize, emphasis: .semibold),
            ink
        )
        let lines = empty.lines.map { Self.label($0.drawn, font, quiet) }
        let rows = empty.rows.map { row in
            Self.style(
                BarPeekPressLabel(wrappingLabelWithString: row.title),
                font,
                ink
            )
        }
        let width = min(
            Metrics.maxWidth - 2 * Metrics.padH,
            ([title] + lines + rows).map(Self.natural).max() ?? 0
        )
        var y = Metrics.padV
        for (index, field) in ([title] + lines).enumerated() {
            if index == 1 { y += Metrics.headerGap }
            if index > 1 { y += Metrics.rowGap }
            y = placeEmpty(field, at: y, width: width)
        }
        if !rows.isEmpty {
            addRule(at: y + Metrics.groupGap, x: 0, width: width)
            y += 2 * Metrics.groupGap + BarDivider.ruleThickness
        }
        for (index, (field, row)) in zip(rows, empty.rows).enumerated() {
            if index > 0 { y += 2 * Metrics.rowGap }
            y = placeEmpty(field, at: y, width: width)
            let action = Action.landing(row.landing)
            addTarget(action, around: field.frame, inks: [field])
            field.onPress = { [weak self] in self?.act(action) }
            field.setAccessibilityElement(true)
            field.setAccessibilityRole(.button)
            field.setAccessibilityLabel(row.title)
        }
        // The header and its lines read as one, each chord in words.
        title.setAccessibilityElement(true)
        title.setAccessibilityRole(.staticText)
        title.setAccessibilityLabel(empty.spoken)
        lines.forEach { $0.setAccessibilityElement(false) }
        emptyInfo = title
        let size = CGSize(
            width: ceil(width + 2 * Metrics.padH),
            height: ceil(y + Metrics.padV)
        )
        frame.size = size
        return size
    }

    /// Places `field` from `top` wrapped at `width`; returns its end.
    private func placeEmpty(
        _ field: NSTextField,
        at top: CGFloat,
        width: CGFloat
    ) -> CGFloat {
        let height = Self.height(of: field, width: width)
        field.frame = CGRect(
            x: Metrics.padH,
            y: top,
            width: width,
            height: height
        )
        add(field)
        return top + height
    }

    /// Moves VoiceOver's cursor onto the empty state's text, which a
    /// VoiceOver press on the Pocket opened (#2941 ▸ 1).
    func focusEmptyInfo() {
        guard let emptyInfo else { return }
        NSAccessibility.post(
            element: emptyInfo,
            notification: .layoutChanged,
            userInfo: [.uiElements: [emptyInfo]]
        )
    }
}

/// A row label VoiceOver presses as a button (#2941).
final class BarPeekPressLabel: NSTextField {
    var onPress: @MainActor () -> Void = {}

    override func accessibilityPerformPress() -> Bool {
        onPress()
        return true
    }
}
