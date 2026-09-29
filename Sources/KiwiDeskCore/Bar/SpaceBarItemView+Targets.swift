import AppKit

/// The item's click targets (#1528): one per app glyph and one on
/// each side's `+n` disc. A click elsewhere on the chip keeps the
/// Space switch in `mouseDown`.
extension SpaceBarItemView {
    /// Rebuilt with the glyphs, but a target whose windows did not
    /// change is kept, so a render under a resting pointer does not
    /// restart its tooltip.
    func syncTargets() {
        guard let space else {
            glyphTargets.forEach { $0.removeFromSuperview() }
            glyphTargets = []
            overflowTarget?.removeFromSuperview()
            overflowTarget = nil
            leadingTarget?.removeFromSuperview()
            leadingTarget = nil
            return
        }
        let kept =
            glyphTargets.map(\.space) == apps.map { _ in space }
            && glyphTargets.map(\.members) == apps.map(\.windows)
            && glyphTargets.map { $0.accessibilityLabel() }
                == apps.map { Self.glyphLabel($0) }
        if !kept {
            glyphTargets.forEach { $0.removeFromSuperview() }
            glyphTargets = apps.map { app in
                makeTarget(
                    space: space,
                    windows: app.windows,
                    kind: .glyph,
                    label: Self.glyphLabel(app)
                )
            }
        }
        glyphTargets.forEach { $0.actions = glyphActions }
        let shown = collapse == nil
        // Each disc lists its windows nearest the glyphs first, so
        // the leading one reads its side of the row backwards.
        leadingTarget = discTarget(
            leadingTarget,
            space: space,
            windows: shown ? before.windows.reversed() : [],
            label: L(
                "space_bar.overflow.before.ax",
                "Earlier windows not shown: %1$d",
                before.windows.count
            )
        )
        overflowTarget = discTarget(
            overflowTarget,
            space: space,
            windows: shown ? after.windows : [],
            label: L(
                "space_bar.overflow.after.ax",
                "Later windows not shown: %1$d",
                after.windows.count
            )
        )
    }

    /// A `+n` disc's target, kept like the glyphs' while its
    /// windows hold, so a render does not re-insert it (#1315);
    /// nil when the side hides nothing.
    private func discTarget(
        _ current: SpaceBarGlyphTarget?,
        space: SpaceID,
        windows: [WindowID],
        label: String
    ) -> SpaceBarGlyphTarget? {
        if let kept = current, kept.space == space,
            kept.members == windows,
            kept.accessibilityLabel() == label
        {
            kept.actions = glyphActions
            return kept
        }
        current?.removeFromSuperview()
        guard !windows.isEmpty else { return nil }
        return makeTarget(
            space: space,
            windows: windows,
            kind: .overflow,
            label: label
        )
    }

    /// Every live target, the hover reading's candidates.
    var targetsForHover: [SpaceBarGlyphTarget] {
        [leadingTarget].compactMap { $0 } + glyphTargets
            + [overflowTarget].compactMap { $0 }
    }

    /// Whether the glyph at `index` is the hovered target.
    func glyphIsHovered(_ index: Int) -> Bool {
        guard let hoveredTarget, index < glyphTargets.count else {
            return false
        }
        return glyphTargets[index] === hoveredTarget
    }

    /// A target wins wherever it lies, whatever order a re-render
    /// left the glyph views in.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden else { return nil }
        let local = convert(point, from: superview)
        if let hit = targetsForHover.first(where: {
            !$0.isHidden && $0.frame.contains(local)
        }) {
            return hit
        }
        return super.hitTest(point)
    }

    /// A glyph speaks as its app; a group adds its window count.
    static func glyphLabel(_ app: App) -> String {
        guard app.count > 1 else { return app.name }
        return L(
            "space_bar.glyph.ax.group",
            "%1$@, windows: %2$d",
            app.name,
            app.count
        )
    }

    private func makeTarget(
        space: SpaceID,
        windows: [WindowID],
        kind: SpaceBarGlyphPick.Kind,
        label: String
    ) -> SpaceBarGlyphTarget {
        let target = SpaceBarGlyphTarget(
            space: space,
            windows: windows,
            kind: kind,
            label: label
        )
        target.actions = glyphActions
        addSubview(target)
        return target
    }

    /// The square cell at `offset` along the bar axis — the rect
    /// a glyph, a badge and a target share.
    func cellRect(at offset: CGFloat, cell: CGFloat) -> CGRect {
        horizontal
            ? CGRect(
                x: offset,
                y: (bounds.height - cell) / 2,
                width: cell,
                height: cell
            )
            : CGRect(
                x: (bounds.width - cell) / 2,
                y: offset,
                width: cell,
                height: cell
            )
    }
}
