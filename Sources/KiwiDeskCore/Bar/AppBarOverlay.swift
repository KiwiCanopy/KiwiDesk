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
    public struct Item {
        public let id: WindowID
        public let name: String
        public let icon: NSImage?
        /// SketchyBar App Font ligature to render instead of
        /// `icon` (#294); nil = native image. Resolved by the
        /// driver so the overlay stays a dumb renderer.
        public let glyph: String?
        /// Windows behind this item; > 1 for a group of
        /// adjacent same-app windows (shown as a badge).
        public let count: Int

        public init(
            id: WindowID,
            name: String,
            icon: NSImage?,
            glyph: String? = nil,
            count: Int = 1
        ) {
            self.id = id
            self.name = name
            self.icon = icon
            self.glyph = glyph
            self.count = count
        }
    }

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
    /// The Liquid Glass plate under the items when `tabBackground`
    /// resolves to `material` (#390); nil otherwise / below macOS
    /// 26. Stored as a plain view — the concrete type is 26-only.
    var glassPlate: NSView?
    /// `plain`'s shared fill plate — its own view (not the
    /// container layer) so it can hug the run
    /// (`tab_background_fit`, QA 2026-07-19).
    var plainPlate: NSView?
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
        itemContainer.frame =
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
        // per `tab_background_fit`. With no arrow inset the
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
            fit: style.tabBackgroundFit
        )
        // Frame changes ease into place so group expansion
        // (and scroll-follow) widens out instead of popping;
        // fresh views snap. The plates ride the same group —
        // a hug plate must slide with the tabs it wraps.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(
                name: .easeOut
            )
            updatePlates(
                panel,
                style: style,
                strip: strip,
                plateFrame: plateFrame,
                animated: true
            )
            for (index, view) in itemViews.enumerated() {
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
                name: item.name,
                icon: item.icon,
                glyph: item.glyph,
                count: item.count,
                active: active,
                horizontal: m.horizontal,
                style: style
            )
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

    // MARK: - Scroll arrows

    /// Arrows sit at the strip's ends, shown only toward
    /// hidden items; clicking shifts the bar by one slot.
    private func layoutArrows(
        strip: CGRect,
        m: Metrics,
        style: AppBarStyle
    ) {
        backArrow.isHidden =
            m.inset == 0 || scrollOffset <= 0.5
        forwardArrow.isHidden =
            m.inset == 0
            || m.total - m.viewport - scrollOffset <= 0.5
        let zone = Self.arrowZone
        backArrow.frame =
            m.horizontal
            ? CGRect(
                x: 0,
                y: 0,
                width: zone,
                height: strip.height
            )
            : CGRect(
                x: 0,
                y: 0,
                width: strip.width,
                height: zone
            )
        forwardArrow.frame =
            m.horizontal
            ? CGRect(
                x: strip.width - zone,
                y: 0,
                width: zone,
                height: strip.height
            )
            : CGRect(
                x: 0,
                y: strip.height - zone,
                width: strip.width,
                height: zone
            )
        let colors = BarArrowColors(
            text: NSColor(kiwiHex: style.itemColor),
            hoverText: NSColor(kiwiHex: style.hoverItemColor),
            box: NSColor(kiwiHex: style.fillColor),
            hover: NSColor(kiwiHex: style.hoverFillColor),
            cornerRoundness: style.cornerRoundness
        )
        backArrow.configure(
            glyph: m.horizontal ? "◂" : "▴",
            colors: colors
        )
        forwardArrow.configure(
            glyph: m.horizontal ? "▸" : "▾",
            colors: colors
        )
        let step = m.slot + m.gap
        backArrow.onClick = { [weak self] in
            self?.scroll(by: -step)
        }
        forwardArrow.onClick = { [weak self] in
            self?.scroll(by: step)
        }
    }

    private func scroll(by delta: CGFloat) {
        scrollOffset += delta
        render(followingFocus: false)
    }

}
