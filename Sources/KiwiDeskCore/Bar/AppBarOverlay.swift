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
    struct RenderState: Equatable {
        let items: [Item]
        let activeIndex: Int?
        let strip: CGRect
        let style: AppBarLook
        let capAxis: CGFloat?
        /// The Space the items belong to; a change dissolves the
        /// row (#1838).
        let space: SpaceID?
    }

    /// What the last draw read beyond its input (#1901).
    private(set) var drawnEnvironment: BarDrawEnvironment?

    /// Makes the next show draw though its input repeats — for a
    /// path that moved views outside `show`, like a drag (#1901).
    func invalidateRender() { drawnEnvironment = nil }

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
    /// The rule and the floating mark between the tiled row and
    /// its floats (#1826).
    let floatRule = FloatBreakRule()
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
    /// The window each box glass is paired with, by position in
    /// `boxGlasses` (#1831).
    var boxGlassOwners: [WindowID] = []
    /// Members sliding out of a group on a boxed glass run, which
    /// take their glass when the glide lands (#1831).
    var glidingIn: Set<WindowID> = []
    /// Bumped by every render that starts a group glide, so only
    /// the latest glide's landing re-renders.
    var glideGeneration = 0
    var scrollOffset: CGFloat = 0
    /// Follows the focused window unless a manual scroll holds.
    var follow = ShelfFollow<WindowID>()
    var lastMetrics: Metrics?
    /// The style the last render drew, gated once (#1374), which a
    /// scroll re-reads rather than gating again.
    var drawnStyle: AppBarLook?
    private(set) var lastShown: RenderState?
    /// The one frame write the run and its items take; a test
    /// swaps it to see whether a pass asked to travel.
    var moveFrame: BarFrameMove = BarMotion.setFrame(_:to:animated:)
    /// Set by a `show` after a hide, consumed by its render: the
    /// first render of a section appearing lands, never slides.
    private var pendingLanding = false
    /// Set by a `show` for another Space, consumed by its render:
    /// the old row fades out in place and the new fades in (#1838).
    private var pendingDissolve = false

    public init() {
        configureRoot()
    }

    public var isVisible: Bool { lastShown != nil && !root.isHidden }

    /// The slot this section last drew into (AX coordinates) — the
    /// one the shelf places it at.
    var shownStrip: CGRect? { lastShown?.strip }

    /// Renders `items` into `strip` (AX coordinates); `space` is
    /// the Space they belong to.
    public func show(
        items: [Item],
        activeIndex: Int?,
        strip: CGRect,
        style: AppBarLook,
        capAxis: CGFloat? = nil,
        space: SpaceID? = nil
    ) {
        guard !items.isEmpty,
            strip.width >= 1, strip.height >= 1
        else {
            hide()
            return
        }
        let next = RenderState(
            items: items,
            activeIndex: activeIndex,
            strip: strip,
            style: style,
            capAxis: capAxis,
            space: space
        )
        // An identical show draws nothing (#1901).
        let environment = BarDrawEnvironment.current
        if isVisible, lastShown == next, drawnEnvironment == environment {
            WorkMeter.shared.add(\.barShowsSkipped)
            return
        }
        drawnEnvironment = environment
        let appearing = lastShown == nil
        pendingLanding = appearing
        pendingDissolve = !appearing && lastShown?.space != space
        lastShown = next
        let focus = activeIndex.flatMap {
            items.indices.contains($0) ? items[$0].id : nil
        }
        render(followingFocus: follow.follows(focus))
    }

    /// Hides the section, tearing nothing down: its views stay
    /// for the shelf, which draws a leaving section until its leave
    /// lands and shows the root again meanwhile; a hide of a hidden
    /// section writes nothing (#1838).
    public func hide() {
        guard lastShown != nil else { return }
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
        let lands = pendingLanding
        let dissolves = pendingDissolve
        pendingLanding = false
        pendingDissolve = false
        let glide = syncItemViews(
            to: items,
            glass: glassHosting(style) == .boxGlass,
            dissolving: dissolves
        )
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
            lengths: m.lengths,
            gap: m.gap,
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
        let frames = Self.itemFrames(
            in: CGRect(origin: .zero, size: runFrame.size),
            m: m
        )
        let runStart: CGFloat
        if let first = frames.first {
            runStart =
                m.inset
                + (m.horizontal
                    ? first.minX + runFrame.minX : first.minY + runFrame.minY)
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
        standArrivals(glide.arrivals)
        // A group folding or releasing members changes the bar's
        // length, and the shelf re-places the section on the plate
        // glide: the items ride the same glide, so the fold and
        // the re-centring are one motion (#1831).
        let groups = !glide.departures.isEmpty || !glide.arrivals.isEmpty
        (groups ? BarMotion.runPlateGlide : BarMotion.runLayout) {
            moveFrame(itemRun, runFrame, !lands)
            for (index, view) in itemViews.enumerated()
            where view.superview === itemRun {
                moveFrame(view, frames[index], !lands)
            }
            layoutFloatBreak(
                frames: frames,
                m: m,
                depth: depth,
                style: style,
                animated: !lands
            )
            playGroupGlide(
                departures: glide.departures,
                arrivals: glide.arrivals,
                items: items,
                frames: frames
            )
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
            horizontal: m.horizontal,
            leading: m.markLead
        )
        contentFrame = runContent.offsetBy(
            dx: runFrame.minX + itemContainer.frame.minX,
            dy: runFrame.minY + itemContainer.frame.minY
        )
        // Single dispatch for glass hosting mode (#407), on the
        // glide the items took, so a box travels with its item.
        (groups ? BarMotion.runPlateGlide : BarMotion.runLayout) {
            installGlassHosting(
                hosting,
                frames: frames,
                style: style,
                depth: depth,
                animated: !lands
            )
        }
        layoutOverflow(strip: strip, m: m, style: style)
        root.isHidden = false
        onRendered()
    }

}
