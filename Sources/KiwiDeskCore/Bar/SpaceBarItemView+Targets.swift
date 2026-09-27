import AppKit

/// The item's click targets (#1528): one per app glyph and one on
/// the `+n` badge. A click elsewhere on the chip keeps the Space
/// switch in `mouseDown`.
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
        syncOverflowTarget(space: space)
    }

    /// The `+n` target, kept like the glyphs' while its windows
    /// hold, so a render does not re-insert it (#1315).
    private func syncOverflowTarget(space: SpaceID) {
        let wanted =
            collapse == nil && !overflowWindows.isEmpty
            ? overflowWindows : []
        if let kept = overflowTarget, kept.space == space,
            kept.members == wanted
        {
            kept.actions = glyphActions
            return
        }
        overflowTarget?.removeFromSuperview()
        overflowTarget = nil
        guard !wanted.isEmpty else { return }
        overflowTarget = makeTarget(
            space: space,
            windows: wanted,
            kind: .overflow,
            label: L(
                "space_bar.overflow.ax",
                "Windows not shown: %1$d",
                wanted.count
            )
        )
    }

    /// A target wins wherever it lies, whatever order a re-render
    /// left the glyph views in.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden else { return nil }
        let local = convert(point, from: superview)
        let targets = glyphTargets + [overflowTarget].compactMap { $0 }
        if let hit = targets.first(where: {
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
