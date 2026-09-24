import AppKit

/// The App Bar's section of one display's shelf (#293, #1517): it
/// draws into `root`, which `ShelfOverlay` places on the shelf's
/// one panel over the shelf's one plate.
@MainActor
public final class AppBarOverlay {
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
    private struct RenderState {
        let items: [Item]
        let activeIndex: Int?
        let strip: CGRect
        let style: AppBarLook
        let capAxis: CGFloat?
    }

    /// The section's view; the shelf sets its origin, the
    /// section its size.
    let root = FlippedView()
    /// The plate this section's run asks for, in `root`'s
    /// coordinates — the shelf unions it with the other section's.
    var plateFrame: CGRect = .zero
    /// Fires after every render, so the shelf re-lays its plate.
    var onRendered: @MainActor () -> Void = {}
    var itemViews: [AppBarItemView] = []
    let itemContainer = FlippedView()
    /// Hidden-entry counts on each fading end (#1517).
    let backCount = ShelfCountView(side: .before)
    let forwardCount = ShelfCountView(side: .after)
    /// Per-box Liquid Glass views for `boxed + liquid_glass`.
    var boxGlasses: [NSView] = []
    /// Solid backdrops behind per-box glass for tint refraction (#408).
    var boxTints: [NSView] = []
    var scrollOffset: CGFloat = 0
    /// Follows the focused window unless a manual scroll holds.
    var follow = ShelfFollow<WindowID>()
    var lastMetrics: Metrics?
    private var lastShown: RenderState?

    public init() {
        configureRoot()
    }

    public var isVisible: Bool { lastShown != nil && !root.isHidden }

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
        let frames = Self.frames(
            lengths: Array(
                repeating: m.slot,
                count: items.count
            ),
            in: itemContainer.bounds,
            gap: m.gap,
            horizontal: m.horizontal,
            alignment: m.alignment,
            scrolledBy: scrollOffset
        )
        let runStart: CGFloat
        if let first = frames.first {
            runStart = m.horizontal ? first.minX : first.minY
        } else {
            runStart = 0
        }
        let plateFrame = BarPlate.frame(
            strip: strip,
            runStart: runStart,
            runTotal: m.total,
            inset: m.inset,
            gap: m.gap,
            horizontal: m.horizontal,
            fit: style.backgroundFit
        )
        let depth = edge.isHorizontal ? strip.height : strip.width
        self.plateFrame = plateFrame
        let hosting = glassHosting(style)
        BarMotion.runLayout {
            for (index, view) in itemViews.enumerated()
            where view.superview === itemContainer {
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
                active: active,
                horizontal: m.horizontal,
                style: style
            )
            view.isFirstInRun = index == 0
            view.isLastInRun = index == items.count - 1
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
        // Single dispatch for glass hosting mode (#407).
        installGlassHosting(
            hosting,
            frames: frames,
            style: style,
            depth: depth,
            animated: true
        )
        layoutOverflow(strip: strip, m: m, style: style)
        root.isHidden = false
        onRendered()
    }

}
