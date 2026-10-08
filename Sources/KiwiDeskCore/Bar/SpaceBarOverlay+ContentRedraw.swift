import AppKit

/// A show that moves no frame redraws content alone (#2086, owner
/// ruling): a focus change re-tints the Space items' glyphs and
/// renames the front segment, whose length is fixed, so the run,
/// its glass and the shelf around it stay where they are.
extension SpaceBarOverlay {
    /// Where the last render placed the front segment.
    struct FrontPlacement: Equatable {
        let after: CGFloat
        let nameBound: CGFloat
    }

    /// Whether `next` draws every frame `last` drew: the same slot,
    /// look and items in the same places at the same lengths, and a
    /// front segment of the same extent on both or neither.
    func keepsGeometry(_ last: Shown, _ next: Shown) -> Bool {
        guard last.strip == next.strip, last.style == next.style,
            last.stateMarkColors == next.stateMarkColors,
            (last.frontApp == nil) == (next.frontApp == nil),
            last.items.count == next.items.count,
            zip(last.items, next.items).allSatisfy(Self.samePlace)
        else { return false }
        let style = LiquidGlassGate.rendered(next.style)
        let horizontal = style.edge.isHorizontal
        let depth = horizontal ? next.strip.height : next.strip.width
        let extent = { (app: SpaceBarItemView.App?) in
            self.frontExtent(
                app,
                depth: depth,
                horizontal: horizontal,
                style: style
            )
        }
        guard extent(last.frontApp) == extent(next.frontApp)
        else { return false }
        let lengths = { (items: [Item]) in
            Self.itemLengths(
                items,
                depth: depth,
                look: style,
                frontFollows: next.frontApp != nil
            )
        }
        return lengths(last.items) == lengths(next.items)
    }

    private static func samePlace(_ old: Item, _ new: Item) -> Bool {
        old.identity == new.identity && old.active == new.active
            && old.spaceGlyph == new.spaceGlyph
            && old.marker == new.marker && old.collapse == new.collapse
    }

    /// Reconfigures the items that changed since `last` and the
    /// front segment in place, then lets the shelf re-read its
    /// hover and peek, which skip a show that repeats.
    func redrawContent(since last: Shown, at front: FrontPlacement) {
        guard let state = lastShown else { return }
        let style = LiquidGlassGate.rendered(state.style)
        let horizontal = style.edge.isHorizontal
        for (index, item) in state.items.enumerated()
        where index < itemViews.count && item != last.items[index] {
            configure(
                itemViews[index],
                item,
                horizontal: horizontal,
                style: style,
                stateMarkColors: state.stateMarkColors
            )
        }
        renderFrontSegment(
            state.frontApp,
            after: front.after,
            strip: state.strip,
            nameBound: front.nameBound,
            style: style,
            horizontal: horizontal
        )
        if let run = scrollRun {
            scrollRun = ScrollRun(
                items: state.items,
                frames: run.frames,
                lengths: run.lengths,
                entries: run.entries,
                front: run.front,
                total: run.total,
                viewport: run.viewport,
                gap: run.gap,
                depth: run.depth,
                horizontal: run.horizontal,
                strip: run.strip,
                style: run.style,
                content: run.content,
                rides: run.rides,
                frontApp: run.frontApp == nil ? nil : state.frontApp,
                frontStart: run.frontStart
            )
        }
        onRendered()
    }

    /// One item view's content — the render's and the redraw's.
    func configure(
        _ view: SpaceBarItemView,
        _ item: Item,
        horizontal: Bool,
        style: SpaceBarLook,
        stateMarkColors: StateMarkColors
    ) {
        view.configure(
            identity: item.identity,
            spaceGlyph: item.spaceGlyph,
            apps: item.apps,
            active: item.active,
            horizontal: horizontal,
            style: style,
            stateMarkColors: stateMarkColors,
            before: item.before,
            after: item.after,
            drawn: item.drawn,
            marker: item.marker,
            collapse: item.collapse
        )
    }
}
