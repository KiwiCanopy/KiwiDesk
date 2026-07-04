import AppKit

/// The indicator bar: a non-activating panel listing the
/// windows of a container, one item per window, the active
/// one highlighted (or left out as a gap). Items that don't
/// fit the strip scroll instead of shrinking: the bar follows
/// the focused item, and clickable arrows appear over the
/// ends that hide more items.
///
/// Deliberately generic — it renders items into a strip
/// handed to it in AX coordinates and knows nothing about
/// layouts. Monocle is its first client; Lua-registered
/// custom layouts can adopt it later without a rewrite.
@MainActor
public final class IndicatorBarOverlay {
    public struct Item {
        public let id: WindowID
        public let name: String
        public let icon: NSImage?

        public init(
            id: WindowID,
            name: String,
            icon: NSImage?
        ) {
            self.id = id
            self.name = name
            self.icon = icon
        }
    }

    /// Click-to-focus hook; wired to `KiwiCore.focusWindow`.
    public var onSelect: @MainActor (WindowID) -> Void = {
        _ in
    }

    /// Depth of the clickable scroll-arrow zones at the
    /// strip's ends; doubles as the visibility margin the
    /// active item keeps clear of them.
    nonisolated static let arrowZone: CGFloat = 24

    /// The inputs of the last `show()`, kept so manual arrow
    /// scrolling can re-render without a new layout pass from
    /// the core.
    private struct RenderState {
        let items: [Item]
        let activeIndex: Int?
        let strip: CGRect
        let params: MonocleParams
    }

    private var panel: NSPanel?
    private var itemViews: [IndicatorBarItemView] = []
    private let itemContainer = FlippedView()
    private let backArrow = IndicatorBarArrowView()
    private let forwardArrow = IndicatorBarArrowView()
    private var scrollOffset: CGFloat = 0
    private var lastShown: RenderState?

    public init() {}

    public var isVisible: Bool { panel?.isVisible ?? false }

    /// Renders `items` into `strip` (AX coordinates).
    public func show(
        items: [Item],
        activeIndex: Int?,
        strip: CGRect,
        params: MonocleParams
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
            params: params
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
    private func render(followingFocus: Bool) {
        guard let state = lastShown else { return }
        let items = state.items
        let activeIndex = state.activeIndex
        let strip = state.strip
        let params = state.params
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let bar = params.bar
        styleContainer(panel, params: params)
        syncItemViewCount(items.count)
        let m = metrics(
            strip: strip,
            count: items.count,
            params: params
        )
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
            scrolledBy: scrollOffset
        )
        for (index, item) in items.enumerated() {
            let view = itemViews[index]
            view.frame = frames[index]
            let active = index == activeIndex
            // "gap" active style: the focused window's slot
            // stays empty instead of being highlighted.
            view.isHidden =
                active && bar.activeStyle == .gap
            view.configure(
                id: item.id,
                name: item.name,
                icon: item.icon,
                active: active,
                horizontal: m.horizontal,
                params: params
            )
            view.onSelect = { [weak self] id in
                self?.onSelect(id)
            }
        }
        layoutArrows(strip: strip, m: m, params: params)
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
        params: MonocleParams
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
        backArrow.style(
            glyph: m.horizontal ? "◂" : "▴",
            params: params
        )
        forwardArrow.style(
            glyph: m.horizontal ? "▸" : "▾",
            params: params
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

    // MARK: - Panel plumbing

    /// Underline style draws all names on one shared box; the
    /// other styles put boxes on the items and keep the strip
    /// itself in the (default transparent) background color.
    private func styleContainer(
        _ panel: NSPanel,
        params: MonocleParams
    ) {
        guard let layer = panel.contentView?.layer else {
            return
        }
        layer.masksToBounds = true
        layer.cornerRadius =
            params.bar.style == .pills
            ? 0 : params.bar.cornerRadius
        let background =
            params.bar.style == .underline
            ? params.bar.boxColor
            : params.bar.backgroundColor
        layer.backgroundColor =
            NSColor(kiwiHex: background).cgColor
    }

    private func syncItemViewCount(_ count: Int) {
        while itemViews.count > count {
            itemViews.removeLast().removeFromSuperview()
        }
        while itemViews.count < count {
            let view = IndicatorBarItemView()
            itemViews.append(view)
            itemContainer.addSubview(view)
        }
    }

    /// Flipped so the first item sits at the visual top of
    /// vertical bars.
    private final class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }

    /// Like the drag visuals' panels, but clickable: items
    /// focus their window on click. `.nonactivatingPanel`
    /// keeps KiwiDesk out of the key window order anyway.
    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]
        let view = FlippedView()
        view.wantsLayer = true
        panel.contentView = view
        // Items render inside a clipping viewport so that,
        // while scrolled, the cut-off item ends a gap short
        // of the arrows instead of sliding under them.
        itemContainer.wantsLayer = true
        itemContainer.layer?.masksToBounds = true
        view.addSubview(itemContainer)
        view.addSubview(backArrow)
        view.addSubview(forwardArrow)
        return panel
    }
}
