import AppKit

/// The Space Bar panel for one display (#293): renders Space
/// items into a strip handed to it in AX coordinates. A dumb
/// renderer like `AppBarOverlay` — the driver resolves state,
/// identifiers, and glyphs. Items size to their content
/// (identifier + app glyphs), so lengths vary per item. When the
/// run overflows the strip the bar scrolls rather than clipping
/// (#385): items render inside a clipping viewport inset by an
/// arrow zone at each end, with clickable chevrons toward the
/// hidden Spaces and a scroll that follows the active Space — the
/// App Bar's overflow model (see `SpaceBarOverlay+Scroll`).
@MainActor
public final class SpaceBarOverlay {
    /// One Space's resolved content.
    public struct Item {
        let space: SpaceID
        let spaceGlyph: SpaceBarItemView.Identifier
        let apps: [SpaceBarItemView.App]
        let active: Bool
        /// Windows hidden past the glyph cap ("+n" badge).
        let overflow: Int
    }

    /// Click-to-focus hook; wired to `KiwiCore.focusSpace`.
    public var onSelect: @MainActor (SpaceID) -> Void = { _ in }

    private var panel: NSPanel?
    var itemViews: [SpaceBarItemView] = []
    /// The clipping item viewport (#385): items and the trailing
    /// front segment render inside it, inset by an arrow zone at
    /// each end while the run overflows, so a half-scrolled item
    /// is cut a gap short of the arrows instead of sliding under
    /// them. Spans the full strip while everything fits.
    let itemContainer = AppBarOverlay.FlippedView()
    let backArrow = BarArrowView()
    let forwardArrow = BarArrowView()
    /// Whole-bar scroll offset (#385); 0 while the run fits.
    var scrollOffset: CGFloat = 0
    /// Cached scroll geometry, kept for the arrow-zone hit test
    /// and the drag autoscroll stepping between renders (#385).
    var scrollGeom: ScrollGeom?
    /// The running drag-autoscroll task and its direction while a
    /// window drag dwells over an arrow zone (#385); nil when idle.
    /// A `Task` loop (not a `Timer`) mirrors the drop coordinator's
    /// dwell — a `Timer`'s `@Sendable` block can't weak-capture
    /// this non-`Sendable` `@MainActor` type in a release build.
    var autoScrollTask: Task<Void, Never>?
    var autoScrollDirection: ScrollArrow?
    /// Last-rendered strip in AX coordinates and the per-item
    /// frames within it (strip-local, top-left), for the #372
    /// drag-drop hit test. Kept in lockstep with what `render()`
    /// drew — clamped to the visible viewport so a point over an
    /// arrow zone or a scrolled-off item is never a drop target.
    var hitStrip: CGRect = .zero
    var hitFrames: [(space: SpaceID, frame: CGRect)] = []
    // The optional trailing front-app segment (#293 verdict 6):
    // a divider rule, the focused app's glyph, and — on
    // horizontal bars only — its name.
    let frontDivider = NSView()
    let frontIcon = NSImageView()
    let frontGlyph: NSTextField = {
        let tf = NSTextField(labelWithString: "")
        tf.alignment = .center
        tf.setAccessibilityElement(false)
        return tf
    }()
    let frontName = NSTextField(labelWithString: "")
    private var lastShown:
        (
            items: [Item],
            frontApp: SpaceBarItemView.App?,
            strip: CGRect,
            style: SpaceBarStyle
        )?

    public init() {}

    public var isVisible: Bool { panel?.isVisible ?? false }

    /// Renders `items` into `strip` (AX coordinates).
    /// `frontApp` is the trailing segment's app; nil while the
    /// toggle is off or no window is focused.
    func show(
        items: [Item],
        frontApp: SpaceBarItemView.App? = nil,
        strip: CGRect,
        style: SpaceBarStyle
    ) {
        guard !items.isEmpty,
            strip.width >= 1, strip.height >= 1
        else {
            hide()
            return
        }
        lastShown = (items, frontApp, strip, style)
        render(followingActive: true)
    }

    public func hide() {
        lastShown = nil
        hitStrip = .zero
        hitFrames = []
        scrollOffset = 0
        scrollGeom = nil
        cancelDragAutoScroll()
        panel?.orderOut(nil)
    }

    /// Whether the panel is on screen — the hit test is only
    /// meaningful for a visible bar.
    var isPanelVisible: Bool { panel?.isVisible == true }

    // MARK: - Rendering

    /// One layout pass over the last shown state. `show()`
    /// follows the active Space into view; a manual arrow or
    /// autoscroll re-renders without that adjustment so it isn't
    /// snapped straight back (the App Bar's `followingFocus`).
    func render(followingActive: Bool) {
        guard let state = lastShown else { return }
        let (items, frontApp, strip, style) = state
        let panel = self.panel ?? makePanel()
        self.panel = panel
        styleContainer(panel, style: style, strip: strip)
        syncItemViewCount(items.count)
        let horizontal = style.edge.isHorizontal
        let depth = horizontal ? strip.height : strip.width
        let axis = horizontal ? strip.width : strip.height
        let gap = style.boxGap
        let lengths = items.map { item in
            style.boxSize > 0
                ? style.boxSize
                : SpaceBarItemView.autoLength(
                    appCount: item.apps.count,
                    overflow: item.overflow,
                    depth: depth
                )
        }
        // Items plus the trailing front segment align as ONE run
        // (an end-aligned bar ends at the rim including the
        // segment) — and scroll as one when the run overflows.
        let front = frontExtent(
            frontApp,
            depth: depth,
            horizontal: horizontal,
            style: style
        )
        let total = Self.runTotal(
            lengths: lengths,
            gap: gap,
            frontExtent: front
        )
        let (inset, viewport) = Self.scrollViewport(
            axis: axis,
            total: total,
            gap: gap
        )
        scrollOffset = Self.scrollOffset(
            current: scrollOffset,
            lengths: lengths,
            gap: gap,
            frontExtent: front,
            activeIndex: followingActive ? activeIndex(items) : nil,
            viewport: viewport,
            margin: gap
        )
        placeItemContainer(
            inset: inset,
            viewport: viewport,
            strip: strip,
            horizontal: horizontal
        )
        let metrics = Self.runMetrics(
            lengths: lengths,
            gap: gap,
            frontExtent: front,
            strip: strip,
            viewport: viewport,
            horizontal: horizontal,
            alignment: style.alignment,
            pad: SpaceBarItemView.pad,
            scrollOffset: scrollOffset
        )
        recordHitFrames(
            items: items,
            frames: metrics.itemFrames,
            strip: strip
        )
        for (index, item) in items.enumerated() {
            let view = itemViews[index]
            view.frame = metrics.itemFrames[index]
            view.configure(
                space: item.space,
                spaceGlyph: item.spaceGlyph,
                apps: item.apps,
                active: item.active,
                horizontal: horizontal,
                style: style,
                overflow: item.overflow
            )
            view.onSelect = { [weak self] space in
                self?.onSelect(space)
            }
        }
        renderFrontSegment(
            frontApp,
            after: metrics.frontStart,
            strip: strip,
            viewport: viewport,
            style: style,
            horizontal: horizontal
        )
        layoutArrows(
            strip: strip,
            inset: inset,
            viewport: viewport,
            total: total,
            lengths: lengths,
            gap: gap,
            horizontal: horizontal,
            style: style
        )
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

    /// The index of the active Space, for scroll-follow.
    private func activeIndex(_ items: [Item]) -> Int? {
        items.firstIndex(where: \.active)
    }

    /// Positions the clipping viewport: inset by an arrow zone at
    /// each end while overflowing, the full strip otherwise.
    private func placeItemContainer(
        inset: CGFloat,
        viewport: CGFloat,
        strip: CGRect,
        horizontal: Bool
    ) {
        itemContainer.frame =
            horizontal
            ? CGRect(
                x: inset,
                y: 0,
                width: viewport,
                height: strip.height
            )
            : CGRect(
                x: 0,
                y: inset,
                width: strip.width,
                height: viewport
            )
    }

    /// Records the drag-drop hit frames in strip-local
    /// coordinates, offset by the viewport origin and clamped to
    /// the visible viewport (#385): a point over an arrow zone or
    /// a scrolled-off item resolves to no Space.
    private func recordHitFrames(
        items: [Item],
        frames: [CGRect],
        strip: CGRect
    ) {
        hitStrip = strip
        let container = itemContainer.frame
        hitFrames = zip(items, frames).compactMap { item, frame in
            let stripLocal = frame.offsetBy(
                dx: container.minX,
                dy: container.minY
            )
            let visible = stripLocal.intersection(container)
            guard !visible.isNull, visible.width >= 1,
                visible.height >= 1
            else { return nil }
            return (item.space, visible)
        }
    }

    /// Axis start of the content run per `alignment` (#293
    /// QA). `pad` keeps the run off the strip's rim and floors
    /// every case. Overflowing runs never reach this — they start
    /// at the scroll offset (#385, see `runMetrics`). `pad` is a
    /// parameter (callers pass `SpaceBarItemView.pad`) so this
    /// stays nonisolated and unit-testable.
    nonisolated static func contentStart(
        total: CGFloat,
        axis: CGFloat,
        alignment: SpaceBarStyle.Alignment,
        pad: CGFloat
    ) -> CGFloat {
        switch alignment {
        case .start: return pad
        case .center: return max((axis - total) / 2, pad)
        case .end: return max(axis - total - pad, pad)
        }
    }
}
