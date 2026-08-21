import AppKit

/// The app bar: a non-activating panel listing the windows of a
/// container, one item per window, the active one highlighted
/// (or left out as a gap). Items that don't fit the strip scroll
/// instead of shrinking: the bar follows the focused item, and
/// clickable arrows appear over the ends that hide more items.
///
/// Deliberately generic — it renders items into a strip handed
/// to it in AX coordinates and knows nothing about layouts.
/// Monocle and scrolling both drive it; Lua-registered custom
/// layouts can adopt it later without a rewrite.
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

    /// Depth of the clickable scroll-arrow zones at the
    /// strip's ends; doubles as the visibility margin the
    /// active item keeps clear of them. The shared constant
    /// lives on `BarArrowView` (the Space Bar reuses it, #385).
    nonisolated static let arrowZone = BarArrowView.zone

    /// The inputs of the last `show()`, kept so manual arrow
    /// scrolling can re-render without a new layout pass from
    /// the core.
    private struct RenderState {
        let items: [Item]
        let activeIndex: Int?
        let strip: CGRect
        /// The already-resolved style (global overlaid by the
        /// active layout's overrides) — the overlay is
        /// layout-agnostic. Its `edge` is the stored absolute
        /// edge the bar sits on (#293).
        let style: AppBarStyle
    }

    private var panel: NSPanel?
    var itemViews: [AppBarItemView] = []
    let itemContainer = FlippedView()
    let backArrow = BarArrowView()
    let forwardArrow = BarArrowView()
    /// The Liquid Glass plate under the items when `backgroundStyle`
    /// resolves to `material` (#390); nil otherwise / below macOS
    /// 26. Stored as a plain view — the concrete type is 26-only.
    var glassPlate: NSView?
    /// Per-box Liquid Glass: one `NSGlassEffectView` per item under
    /// `boxed + liquid_glass`, each hosting its item as `contentView`
    /// (piece 2). Empty otherwise / below macOS 26. Plain views —
    /// the concrete type is 26-only (see AppBarOverlay+BoxGlass).
    var boxGlasses: [NSView] = []
    /// Solid colored backdrops behind each per-box glass, filled
    /// with the box Fill so the near-colorless glass refracts a hue
    /// (#408). Kept parallel to `boxGlasses`. Empty / below macOS 26.
    var boxTints: [NSView] = []
    /// The scroll arrows' own frosted backdrop boxes under per-box
    /// glass, so they read as glass, not solid islands. The arrow
    /// stays interactive on top (its own box goes transparent).
    var backArrowGlass: NSView?
    var forwardArrowGlass: NSView?
    /// Colored backdrops behind the arrow glasses (#408), so the
    /// arrows tint with the boxes instead of staying grey.
    var backArrowTint: NSView?
    var forwardArrowTint: NSView?
    /// Colored backdrop behind the single glass plate (plain +
    /// glass, hug and span), filled with the bar Fill (#408).
    var glassTint: NSView?
    /// `plain`'s shared fill plate — its own view (not the
    /// container layer) so it can hug the run
    /// (`background_fit`, QA 2026-07-19).
    var plainPlate: NSView?
    /// Under plain + glass when the run fits (no overflow), the
    /// glass hosts this flipped run wrapper at the hugged plate
    /// frame with the items positioned run-local inside it — so the
    /// frosted plate hugs the run instead of spanning the viewport.
    /// On overflow the glass falls back to hosting `itemContainer`
    /// at the viewport (piece 1). Empty otherwise / below macOS 26.
    var glassRun: AppBarOverlay.FlippedView?
    /// The hugging plate's span geometry from the last render,
    /// so a reorder drag that begins mid-hug can hand the items
    /// back to `itemContainer` and span the plate for the drag
    /// (`spanPlainGlassForDrag`) — the mover and its reflowing
    /// siblings then share one coordinate space.
    struct GlassDragSpan {
        let viewport: CGRect
        let radius: CGFloat
        let tint: String
    }
    var glassDragSpan: GlassDragSpan?
    var scrollOffset: CGFloat = 0
    /// The last render's geometry, kept for the drag
    /// handlers (AppBarOverlay+Drag).
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
        // The shared plate (plain fill / glass) hugs or spans
        // per `background_fit`. With no arrow inset the
        // viewport is the strip, so viewport-local frames are
        // already strip-local; while inset > 0 the plate is
        // full anyway.
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
        // The one hosting mode for this render (#407): prepared
        // (non-target teardown) in the animation group below, then
        // installed post-loop once the item frames are laid out.
        let depth = edge.isHorizontal ? strip.height : strip.width
        let hosting = glassHosting(style, overflow: m.inset > 0)
        // Frame changes ease into place so group expansion
        // (and scroll-follow) widens out instead of popping;
        // fresh views snap. The plates ride the same group —
        // a hug plate must slide with the items it wraps.
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
            for (index, view) in itemViews.enumerated()
            where view.superview === itemContainer {
                // Items hosted in a glass wrapper (per-box, or the
                // plain-glass run) are placed by the glass path;
                // animating them here in container coords would
                // fight that and flicker.
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
            // "gap" indicator: the focused window's slot stays
            // empty instead of being marked.
            view.isHidden =
                active && style.activeIndicator == .gap
            view.configure(
                id: item.id,
                text: item.text,
                icon: item.icon,
                glyph: item.glyph,
                count: item.count,
                active: active,
                horizontal: m.horizontal,
                style: style
            )
            // Only the run's outer items meet a rounded plate end,
            // so only they clip their outer corner (Plain).
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
        // Install the target hosting from the now-laid-out frames
        // (per-box glass and the plain-glass run both position items
        // from them, so this runs after the item loop with the
        // gap-hidden state set). #407: one dispatch, no per-mode
        // branching at the call site.
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
