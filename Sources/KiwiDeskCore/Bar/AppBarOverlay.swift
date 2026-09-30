import AppKit

/// The App Bar's section of one display's shelf (#293, #1517): it
/// draws into `root`, which `ShelfOverlay` places on the shelf's
/// one panel over the shelf's one plate.
@MainActor
public final class AppBarOverlay {
    /// The items' Core answers, the manager's one instance.
    var itemActions: AppBarItemActions?
    /// Click-to-focus hook; wired to `KiwiCore.focusWindow`.
    public var onSelect: @MainActor (WindowID) -> Void = {
        _ in
    }

    /// Drag-and-drop reorder hook (from slot, to slot);
    /// wired to `KiwiCore.moveBarItem`.
    public var onMove: @MainActor (Int, Int) -> Void = {
        _,
        _ in
    }

    /// Cached inputs from last `show()` for manual arrow scrolling.
    struct RenderState {
        let items: [Item]
        let activeIndex: Int?
        let strip: CGRect
        let style: AppBarLook
        let capAxis: CGFloat?
    }

    /// The section's view; the shelf sets its origin, the
    /// section its size.
    let root = ShelfSectionRoot()
    /// The plate this section's run asks for, in `root`'s
    /// coordinates — the shelf unions it with the other section's.
    var plateFrame: CGRect = .zero
    /// The span this section's run draws, in `root`'s coordinates —
    /// what the shelf's section divider centres against (#1779).
    var contentFrame: CGRect = .zero
    /// `contentFrame` in `itemRun`'s coordinates, which a scroll
    /// moves by the run's origin.
    var runContent: CGRect = .zero
    /// Fires after every render, so the shelf re-lays its plate.
    var onRendered: @MainActor () -> Void = {}
    var itemViews: [AppBarItemView] = []
    let itemContainer = FlippedView()
    /// Holds the items and their glass inside the clipping
    /// `itemContainer`; a scroll moves this one view, never each
    /// item, so per-item glass redraws nothing per event.
    let itemRun = FlippedView()
    /// Hidden-entry counts on each fading end (#1517).
    let backCount = ShelfCountView(side: .before)
    let forwardCount = ShelfCountView(side: .after)
    /// The floating mark between the tiled row and its floats
    /// (#1826).
    let floatMark = FloatBreakMark()
    /// The bars' context menus (#1518): held by the section root,
    /// which every view in the section finds by walking up.
    weak var contextMenus: BarContextMenus? {
        didSet { root.contextMenus = contextMenus }
    }
    /// Per-box Liquid Glass views for `boxed + liquid_glass`.
    var boxGlasses: [NSView] = []
    /// Solid backdrops behind per-box glass for tint refraction (#408).
    var boxTints: [GlassBackdrop] = []
    var scrollOffset: CGFloat = 0
    /// Follows the focused window unless a manual scroll holds.
    var follow = ShelfFollow<WindowID>()
    var lastMetrics: Metrics?
    /// The style the last render drew, gated once (#1374), which a
    /// scroll re-reads rather than gating again.
    var drawnStyle: AppBarLook?
    private(set) var lastShown: RenderState?

    public init() {
        configureRoot()
    }

    public var isVisible: Bool { lastShown != nil && !root.isHidden }

    /// The slot this section last drew into (AX coordinates) — the
    /// one the shelf places it at.
    var shownStrip: CGRect? { lastShown?.strip }

    /// Renders `items` into `strip` (AX coordinates).
    public func show(
        items: [Item],
        activeIndex: Int?,
        strip: CGRect,
        style: AppBarLook,
        capAxis: CGFloat? = nil
    ) {
        guard !items.isEmpty,
            strip.width >= 1, strip.height >= 1
        else {
            hide()
            return
        }
        lastShown = RenderState(
            items: items,
            activeIndex: activeIndex,
            strip: strip,
            style: style,
            capAxis: capAxis
        )
        let focus = activeIndex.flatMap {
            items.indices.contains($0) ? items[$0].id : nil
        }
        render(followingFocus: follow.follows(focus))
    }

    public func hide() {
        follow.reset()
        lastShown = nil
        scrollOffset = 0
        root.isHidden = true
        onRendered()
    }

    // MARK: - Rendering

    /// One layout pass over the last shown state. Focus
    /// changes follow the active item into view; manual
    /// arrow scrolling re-renders without that adjustment so
    /// it isn't immediately snapped back.
    func render(followingFocus: Bool) {
        guard let state = lastShown else { return }
        let items = state.items
        let activeIndex = state.activeIndex
        let strip = state.strip
        // The one place the stored style becomes the drawn one
        // (#1374): glass stands down while transparency is reduced.
        let style = LiquidGlassGate.rendered(state.style)
        drawnStyle = style
        let edge = style.edge
        syncItemViewCount(items.count)
        let m = metrics(
            strip: strip,
            count: items.count,
            style: style,
            items: items,
            capAxis: state.capAxis
        )
        lastMetrics = m
        scrollOffset = Self.scrollOffset(
            current: scrollOffset,
            activeIndex: followingFocus ? activeIndex : nil,
            slot: m.slot,
            gap: m.gap,
            count: items.count,
            breakAfter: m.breakAfter,
            breakExtent: m.breakExtent,
            axis: m.viewport,
            margin: ShelfOverflow.followMargin(
                gap: m.gap,
                depth: edge.isHorizontal ? strip.height : strip.width,
                viewport: m.viewport
            )
        )
        let viewport =
            m.horizontal
            ? CGRect(
                x: m.inset,
                y: 0,
                width: m.viewport,
                height: strip.height
            )
            : CGRect(
                x: 0,
                y: m.inset,
                width: strip.width,
                height: m.viewport
            )
        itemContainer.frame = viewport
        let runFrame = ShelfOverflow.runFrame(
            in: itemContainer.bounds,
            offset: scrollOffset,
            horizontal: m.horizontal
        )
        let frames = layoutFloatBreak(
            slots: Self.frames(
                lengths: m.lengths,
                in: CGRect(origin: .zero, size: runFrame.size),
                gap: m.gap,
                horizontal: m.horizontal,
                alignment: m.alignment
            ),
            m: m,
            depth: m.horizontal ? strip.height : strip.width,
            style: style
        )
        let runStart: CGFloat
        if let first = frames.first {
            runStart =
                m.horizontal
                ? first.minX + runFrame.minX : first.minY + runFrame.minY
        } else {
            runStart = 0
        }
        let plateFrame = BarPlate.frame(
            strip: strip,
            runStart: runStart,
            runTotal: m.total,
            gap: m.gap,
            horizontal: m.horizontal,
            fit: style.backgroundFit
        )
        let depth = edge.isHorizontal ? strip.height : strip.width
        self.plateFrame = plateFrame
        let hosting = glassHosting(style)
        // Items leave their glass BEFORE the frame pass, which sets
        // only the ones the container hosts (#1730).
        if hosting != .boxGlass { teardownBoxGlasses() }
        BarMotion.runLayout {
            BarMotion.setFrame(itemRun, to: runFrame, animated: true)
            for (index, view) in itemViews.enumerated()
            where view.superview === itemRun {
                BarMotion.setFrame(
                    view,
                    to: frames[index],
                    animated: true
                )
            }
        }
        for (index, item) in items.enumerated() {
            let view = itemViews[index]
            let active = index == activeIndex
            view.isHidden = false
            view.configure(
                id: item.id,
                name: item.name,
                text: item.text,
                icon: item.icon,
                glyph: item.glyph,
                count: item.count,
                titleCut: item.titleCut,
                floating: item.floating,
                active: active,
                horizontal: m.horizontal,
                style: style
            )
            view.itemActions = itemActions
            view.members = item.members
            let place = Self.runPlace(index: index, count: items.count)
            view.isFirstInRun = place.first
            view.isLastInRun = place.last
            view.onSelect = { [weak self] id in
                self?.onSelect(id)
            }
            view.onDragMoved = { [weak self] view, point in
                self?.dragMoved(view, to: point)
            }
            view.onDragEnded = { [weak self] view in
                self?.dragEnded(view)
            }
        }
        runContent = drawnContent(
            frames: frames,
            strip: strip,
            horizontal: m.horizontal
        )
        contentFrame = runContent.offsetBy(
            dx: runFrame.minX,
            dy: runFrame.minY
        )
        // Single dispatch for glass hosting mode (#407).
        BarMotion.runLayout {
            installGlassHosting(
                hosting,
                frames: frames,
                style: style,
                depth: depth,
                animated: true
            )
        }
        layoutOverflow(strip: strip, m: m, style: style)
        root.isHidden = false
        onRendered()
    }

}
