import AppKit

/// Non-activating overlay panel displaying window items in AX
/// coordinates; the style's `edge` is the stored absolute edge
/// the bar sits on (#293).
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

    /// Depth of scroll-arrow zones at strip ends (`BarArrowView.zone`, #385).
    nonisolated static let arrowZone = BarArrowView.zone

    /// Cached inputs from last `show()` for manual arrow scrolling.
    private struct RenderState {
        let items: [Item]
        let activeIndex: Int?
        let strip: CGRect
        let style: AppBarStyle
    }

    private var panel: NSPanel?
    var itemViews: [AppBarItemView] = []
    let itemContainer = FlippedView()
    let backArrow = BarArrowView()
    let forwardArrow = BarArrowView()
    /// Liquid Glass plate under items for material background (#390).
    var glassPlate: NSView?
    /// Per-box Liquid Glass views for `boxed + liquid_glass`.
    var boxGlasses: [NSView] = []
    /// Solid backdrops behind per-box glass for tint refraction (#408).
    var boxTints: [NSView] = []
    /// Scroll arrows frosted backdrop boxes.
    var backArrowGlass: NSView?
    var forwardArrowGlass: NSView?
    /// Tinted backdrops behind arrow glasses (#408).
    var backArrowTint: NSView?
    var forwardArrowTint: NSView?
    /// Colored backdrop behind single glass plate (#408).
    var glassTint: NSView?
    /// Shared fill plate for plain style (`background_fit`, QA 2026-07-19).
    var plainPlate: NSView?
    /// Flipped run wrapper for plain + glass without overflow.
    var glassRun: AppBarOverlay.FlippedView?
    /// Hugging plate span geometry for reorder drag transitions.
    struct GlassDragSpan {
        let viewport: CGRect
        let radius: CGFloat
        let tint: String
    }
    var glassDragSpan: GlassDragSpan?
    var scrollOffset: CGFloat = 0
    var lastMetrics: Metrics?
    private var lastShown: RenderState?

    public init() {}

    public var isVisible: Bool { panel?.isVisible ?? false }

    /// Renders `items` into `strip` (AX coordinates).
    public func show(
        items: [Item],
        activeIndex: Int?,
        strip: CGRect,
        style: AppBarStyle
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
            style: style
        )
        render(followingFocus: true)
    }

    public func hide() {
        lastShown = nil
        scrollOffset = 0
        panel?.orderOut(nil)
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
        let style = state.style
        let edge = state.style.edge
        let panel = self.panel ?? makePanel()
        self.panel = panel
        // The plain strip rounds against its real (clamped) cross
        // depth, not the configured thickness, so a strip squeezed
        // by a small usable area can't over-round.
        styleContainer(
            panel,
            style: style,
            depth: edge.isHorizontal ? strip.height : strip.width
        )
        syncItemViewCount(items.count)
        let m = metrics(
            strip: strip,
            count: items.count,
            style: style,
            items: items
        )
        lastMetrics = m
        scrollOffset = Self.scrollOffset(
            current: scrollOffset,
            activeIndex: followingFocus ? activeIndex : nil,
            slot: m.slot,
            gap: m.gap,
            count: items.count,
            axis: m.viewport,
            margin: m.gap
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
        let hosting = glassHosting(style, overflow: m.inset > 0)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(
                name: .easeOut
            )
            prepareGlassHosting(
                hosting,
                panel: panel,
                style: style,
                strip: strip,
                plateFrame: plateFrame,
                viewport: viewport,
                animated: true
            )
            // Items hosted in a glass wrapper are placed by the
            // glass path; animating them here in container coords
            // would fight that and flicker.
            for (index, view) in itemViews.enumerated()
            where view.superview === itemContainer {
                if view.frame == .zero {
                    view.frame = frames[index]
                } else {
                    view.animator().frame = frames[index]
                }
            }
        }
        for (index, item) in items.enumerated() {
            let view = itemViews[index]
            let active = index == activeIndex
            // "gap" indicator: focused window slot stays empty.
            view.isHidden =
                active && style.activeIndicator == .gap
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
            panel: panel,
            frames: frames,
            viewport: viewport,
            plateFrame: plateFrame,
            style: style,
            depth: depth,
            animated: true
        )
        layoutArrows(strip: strip, m: m, style: style)
        panel.setFrame(
            GeometryUtils.flip(
                strip,
                primaryHeight: GeometryUtils.primaryHeight
            ),
            display: true
        )
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

}
