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

    /// The pill's own HUD timings — expand settles in, holds long
    /// enough to READ, collapses a touch snappier. Deliberately
    /// FIXED, not bound to the window animation-speed setting (like
    /// the border ring's timings and macOS's own volume/brightness
    /// HUDs): the hold is a reading duration, and a user who slows
    /// window tiling to watch it glide should not get a pill that
    /// also crawls open. Only the snap-back `delay` (a `flash` arg)
    /// tracks the setting, because it waits on a window animation.
    private static let expandDuration: TimeInterval = 0.22
    private static let holdDuration: TimeInterval = 1.6
    private static let collapseDuration: TimeInterval = 0.16

    private var panel: NSPanel?
    private let plate = StickyIndicatorPlate()
    private let target: CGWindowID
    /// The scope glyph this chip currently wears (#445): `infinity`
    /// (global) or `pin.fill` (display). Set every sync before
    /// `update`, so a scope flip lands on the next retile.
    private var symbolName = StickyStyle.symbolName
    /// Current visual width of the mark — collapsed `size`, or the
    /// expanded pill width. `update` re-corners against this so a
    /// frame follow arriving mid-pill keeps the plate anchored.
    private var currentWidth: CGFloat = size
    /// Deferred expand (after the snap-back settles) and auto-
    /// collapse timers — both cancelled/restarted on a repeat flash
    /// so a rapid series of rejected drags never flickers.
    private var expandWork: DispatchWorkItem?
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

    /// Tints the chip's glyph (and, when expanded, the pill's
    /// home-space name) to the sticky mark color (#429); empty =
    /// "Automatic" (adaptive `.labelColor`). Set every sync before
    /// `update`, so a color change lands on the next retile.
    func setMarkColor(_ hex: String) {
        plate.setMarkColor(hex)
    }

    /// Sets the chip's scope glyph (#445). Applied to the live
    /// plate at once when the panel already exists; otherwise
    /// `makePanel` reads `symbolName` on first show.
    func setSymbol(_ name: String) {
        guard name != symbolName else { return }
        symbolName = name
        if panel != nil { applySymbol() }
    }

    /// Loads `symbolName` into the plate's glyph image.
    private func applySymbol() {
        plate.symbol.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: L(
                "sticky.indicator.ax",
                "Sticky window"
            )
        )
    }

    func hide() {
        expandWork?.cancel()
        expandWork = nil
        collapseWork?.cancel()
        collapseWork = nil
        // Retire in the collapsed state so a later re-show (a
        // `hide` not paired with a retire) can't resurrect the
        // chip mid-pill.
        currentWidth = Self.size
        plate.setNameShown(false, animated: false, duration: 0)
        panel?.orderOut(nil)
    }

    /// Waits `delay` for the snap-back animation to settle (so the
    /// pill doesn't chase a still-moving window), then briefly
    /// expands the chip into a pill showing `format` with `mark`
    /// substituted, then auto-collapses (#421). `delay` tracks the
    /// caller's relayout duration, so a slow/long snap-back holds
    /// the pill back exactly as long as the window travels. A no-op
    /// if the chip isn't shown.
    func flash(format: String, mark: SpaceMark, delay: TimeInterval) {
        guard panel != nil, lastFrame != nil else { return }
        expandWork?.cancel()
        collapseWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.expandThenHold(format: format, mark: mark)
        }
        expandWork = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + max(0, delay),
            execute: work
        )
    }

    /// Expands to fit the content (clamped to the window so the
    /// pill never overruns its own edge), holds, then collapses.
    private func expandThenHold(format: String, mark: SpaceMark) {
        guard let frame = lastFrame else { return }
        let width = min(
            plate.prepare(format: format, mark: mark),
            frame.width - Self.inset * 2
        )
        setPill(width: width, nameShown: true, on: frame)

        let work = DispatchWorkItem { [weak self] in
            guard let self, let frame = self.lastFrame else {
                return
            }
            self.setPill(
                width: Self.size,
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

    /// Animates plate width and the name/shape morph together.
    /// `StickyIndicatorPlate.layout()` reflows the glyph and name
    /// from the live bounds each animation step, so the glyph
    /// holds its screen position; the plate owns the name fade and
    /// corner radius (`setNameShown`). Reduce Motion swaps the
    /// morph for an instant show/hide.
    private func setPill(
        width: CGFloat,
        nameShown: Bool,
        on frame: CGRect
    ) {
        currentWidth = width
        let rect = chipRect(for: frame, width: width)
        guard let panel else { return }

        if reduceMotion {
            panel.setFrame(rect, display: true)
            plate.setNameShown(nameShown, animated: false, duration: 0)
            return
        }
        NSAnimationContext.runAnimationGroup { ctx in
            let duration =
                nameShown
                ? Self.expandDuration : Self.collapseDuration
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(
                name: nameShown ? .easeOut : .easeIn
            )
            panel.animator().setFrame(rect, display: true)
            plate.setNameShown(
                nameShown,
                animated: true,
                duration: duration
            )
        }
        if nameShown { popEntrance() }
    }

    /// A brief scale overshoot on every pill entrance. Its job is
    /// the keyboard refusal, which has no snap-back motion of its own
    /// so a keypress would otherwise feel dead (ui-designer
    /// 2026-07-22); on the mouse-drag pill (#421) the snap-back
    /// already acknowledges, so there the pop is just a small
    /// entrance flourish — one behavior on both paths, no
    /// per-caller gating. Deliberately the pill's own body, not the
    /// ring rubber-band (#436): a third, smallest vocabulary bound to
    /// the cue that explains, keeping "your move bounced" (ring) and
    /// "here's why" (pill) distinct. Guarded by Reduce Motion via the
    /// `setPill` caller, which skips this whole branch.
    private func popEntrance() {
        guard let layer = plate.layer else { return }
        let pop = CAKeyframeAnimation(keyPath: "transform.scale")
        pop.values = [1.0, 1.045, 1.0]
        pop.keyTimes = [0, 0.45, 1.0]
        pop.duration = 0.13
        pop.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeIn),
        ]
        layer.add(pop, forKey: "entrancePop")
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
        // `.transient` hides this chip/pill overlay in Exposé and
        // Mission Control at the compositor level, so it vanishes
        // with the swipe and restores on exit with no handler lag.
        panel.collectionBehavior = [
            .transient,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]
        applySymbol()
        panel.contentView = plate
        return panel
    }
}
