import AppKit

/// The on-window sticky mark (#414): a small chip wearing the
/// sticky symbol, hugging its window's top-RIGHT corner
/// (top-left belongs to the traffic lights). A border sibling,
/// deliberately independent of `border.enabled` — borders are
/// optional and often off, but a sticky window's state is
/// otherwise invisible.
///
/// AppKit only: a passive marker needs none of the border's
/// SkyLight fast path. The panel stacks directly above its
/// target window, so unrelated windows layered over the target
/// still cover the mark (same band trick as the border's
/// below-order, inverted).
///
/// On demand it expands into a PILL naming the window's home
/// space (#421): the glyph stays pinned in the rightmost square
/// (its screen position never moves) while the plate grows
/// leftward to reveal the space name, then collapses back. Shown
/// only at the friction moment — a tiled-sticky traveler snapping
/// back on a foreign space — so nothing changes for the common
/// case (ui-designer 2026-07-21).
@MainActor
final class StickyIndicatorOverlay {
    /// Collapsed chip square and its inset from the window
    /// corner. Final size picked by eye (#414).
    static let size: CGFloat = StickyIndicatorPlate.size
    static let inset: CGFloat = 6

    /// Expand settles in; hold; collapse exits a touch snappier.
    private static let expandDuration: TimeInterval = 0.22
    private static let holdDuration: TimeInterval = 1.6
    private static let collapseDuration: TimeInterval = 0.16

    private var panel: NSPanel?
    private let plate = StickyIndicatorPlate()
    private let target: CGWindowID
    /// Current visual width of the mark — collapsed `size`, or the
    /// expanded pill width. `update` re-corners against this so a
    /// frame follow arriving mid-pill keeps the plate anchored.
    private var currentWidth: CGFloat = size
    /// Auto-collapse timer, cancelled/restarted on a repeat flash
    /// so a rapid series of rejected drags never flickers.
    private var collapseWork: DispatchWorkItem?
    /// The last window frame this chip positioned against (AX
    /// coords) — the observable seam that lets the manager's
    /// WS-tracking guard be tested (a suppressed `follow` leaves
    /// this unchanged; `reposition` advances it).
    private(set) var lastFrame: CGRect?

    init(window: CGWindowID) {
        target = window
    }

    /// Places the chip at `frame`'s top-right (AX coords), its
    /// right edge fixed at the window corner so the glyph never
    /// moves as the pill widens leftward. Position only —
    /// stacking is `order()`'s job, asserted on sync, never per
    /// tick: a WindowServer reorder per move event made the chip
    /// visibly lag behind its window (the borders' one-order-per-
    /// sync rule, owner QA 2026-07-21).
    func update(frame: CGRect) {
        lastFrame = frame
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.setFrame(
            chipRect(for: frame, width: currentWidth),
            display: false
        )
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    /// Stacks the chip directly above its target window. Called
    /// on sync (steady state), not per follow tick.
    func order() {
        panel?.order(.above, relativeTo: Int(target))
    }

    func hide() {
        collapseWork?.cancel()
        collapseWork = nil
        panel?.orderOut(nil)
    }

    /// Briefly expands into a pill naming the home space, then
    /// auto-collapses (#421). A no-op if the chip isn't shown.
    func flash(spaceName: String) {
        guard panel != nil, let frame = lastFrame else { return }
        let width = plate.expandedWidth(for: spaceName)
        setPill(
            width: width,
            radius: StickyIndicatorPlate.expandedRadius,
            nameShown: true,
            on: frame
        )

        collapseWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let frame = self.lastFrame else {
                return
            }
            self.setPill(
                width: Self.size,
                radius: StickyIndicatorPlate.collapsedRadius,
                nameShown: false,
                on: frame
            )
        }
        collapseWork = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.holdDuration,
            execute: work
        )
    }

    /// Animates plate width, corner radius and the name's fade
    /// together. `StickyIndicatorPlate.layout()` reflows the glyph
    /// and name from the live bounds each animation step, so the
    /// glyph holds its screen position. Reduce Motion swaps the
    /// morph for an instant show/hide.
    private func setPill(
        width: CGFloat,
        radius: CGFloat,
        nameShown: Bool,
        on frame: CGRect
    ) {
        currentWidth = width
        let rect = chipRect(for: frame, width: width)
        guard let panel else { return }

        if reduceMotion {
            panel.setFrame(rect, display: true)
            plate.name.alphaValue = nameShown ? 1 : 0
            plate.layer?.cornerRadius = radius
            return
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration =
                nameShown
                ? Self.expandDuration : Self.collapseDuration
            ctx.timingFunction = CAMediaTimingFunction(
                name: nameShown ? .easeOut : .easeIn
            )
            panel.animator().setFrame(rect, display: true)
            plate.name.animator().alphaValue = nameShown ? 1 : 0
            plate.animateCornerRadius(to: radius, over: ctx.duration)
        }
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared
            .accessibilityDisplayShouldReduceMotion
    }

    /// The mark's screen rect for a window `frame`: right edge
    /// pinned at the corner (`inset` in), `width` growing left.
    private func chipRect(
        for frame: CGRect,
        width: CGFloat
    ) -> CGRect {
        let chip = CGRect(
            x: frame.maxX - width - Self.inset,
            y: frame.minY + Self.inset,
            width: width,
            height: Self.size
        )
        return GeometryUtils.flip(
            chip,
            primaryHeight: GeometryUtils.primaryHeight
        )
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: CGRect(
                x: 0,
                y: 0,
                width: Self.size,
                height: Self.size
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        // Normal level + relative order: the chip shares its
        // target's band so windows above the target also cover
        // the chip (the border panel's stacking, inverted).
        panel.level = .normal
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]
        plate.symbol.image = NSImage(
            systemSymbolName: StickyStyle.symbolName,
            accessibilityDescription: L(
                "sticky.indicator.ax",
                "Sticky window"
            )
        )
        panel.contentView = plate
        return panel
    }
}
