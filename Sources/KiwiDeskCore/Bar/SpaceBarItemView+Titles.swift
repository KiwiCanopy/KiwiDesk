import AppKit

/// Inline window titles share the glyph's click target and the
/// shelf's font, sizing and Reduce Motion gates.
extension SpaceBarItemView {
    static func inlineTitleWidth(
        _ app: App,
        depth: CGFloat,
        look: SpaceBarLook
    ) -> CGFloat {
        guard look.edge.isHorizontal, let title = app.inlineTitle else {
            return 0
        }
        let measure = NSTextField(labelWithString: title)
        measure.font = look.shelf.textFont(
            ofSize: look.titleFontSize(forDepth: depth)
        )
        measure.sizeToFit()
        return pad + ceil(measure.frame.width) + pad
    }

    static func inlineTitleExtent(
        _ apps: [App],
        depth: CGFloat,
        look: SpaceBarLook
    ) -> CGFloat {
        apps.reduce(0) {
            $0 + inlineTitleWidth($1, depth: depth, look: look)
        }
    }

    func inlineTitleWidth(at index: Int) -> CGFloat {
        guard horizontal, apps.indices.contains(index) else { return 0 }
        return Self.inlineTitleWidth(apps[index], depth: depth, look: style)
    }

    func syncInlineTitles(keepsSpace: Bool) {
        if !keepsSpace {
            titleViews.forEach { $0.removeFromSuperview() }
            titleViews = []
            titleViewWindowKeys = []
        }
        for (windows, label) in zip(titleViewWindowKeys, titleViews) {
            let leaves = !apps.contains { $0.windows == windows }
            if pendingInlineWalk && leaves && !label.isHidden {
                leavingViews.append(label)
            } else {
                label.removeFromSuperview()
            }
        }
        titleViews = apps.map { _ in
            let label = NSTextField(labelWithString: "")
            label.setAccessibilityElement(false)
            label.lineBreakMode = .byTruncatingTail
            label.wantsLayer = true
            addSubview(label, positioned: .below, relativeTo: overflowBadge)
            return label
        }
        titleViewWindowKeys = apps.map(\.windows)
    }

    func layoutInlineTitle(at index: Int, after offset: CGFloat) {
        guard titleViews.indices.contains(index) else { return }
        let label = titleViews[index]
        let width = inlineTitleWidth(at: index)
        label.isHidden = width == 0
        guard width > 0 else { return }
        label.stringValue = apps[index].inlineTitle ?? ""
        label.font = style.shelf.textFont(
            ofSize: style.titleFontSize(forDepth: depth)
        )
        label.sizeToFit()
        let height = label.frame.height
        label.frame = CGRect(
            x: offset + Self.pad,
            y: BarTextGlyph.originY(
                centredOn: depth / 2,
                for: label,
                band: .caps,
                height: height
            ),
            width: max(width - Self.pad * 2, 0),
            height: height
        )
    }

    func styleInlineTitles() {
        for (index, label) in titleViews.enumerated()
        where apps.indices.contains(index) {
            label.textColor =
                glyphIsHovered(index) || (apps[index].focused && isActive)
                ? NSColor(kiwiHex: style.focusedItemColor) : stateColor
        }
    }

    func reportTitleHover(_ target: SpaceBarGlyphTarget?) {
        guard let space else { return }
        let window =
            style.showHoverTitles && horizontal && !isActive
                && target?.kind == .glyph
            ? target?.members.first : nil
        glyphActions?.hover(space, window)
    }
}
