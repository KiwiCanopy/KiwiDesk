import AppKit
import QuartzCore

/// The Space-switch plate slide (#1956): one panel per screen,
/// ordered in on first use and never moved, ordered out or resized
/// while a switch plays. A play fades plates in over the windows
/// shown now, slides them one page as a rigid strip while the
/// windows move underneath, and fades them out over the landed
/// ones. Every motion is `BarMotion`'s and runs in the render
/// server on times taken from the press, so a stalled main turn
/// delays none of it. `SpaceSlidePlan` decides what is drawn.
@MainActor
final class SpaceSlideOverlay {
    private var panels: [DisplayID: NSPanel] = [:]

    /// AppKit keeps a visible panel alive after its owner is gone
    /// (#1868).
    isolated deinit {
        for panel in panels.values { panel.orderOut(nil) }
    }

    /// The Reduce Motion read the switch takes — live by default;
    /// `makeTestCore` pins it ON, so a suite's switch is instant
    /// unless it states otherwise.
    var reduceMotion: @MainActor () -> Bool = { BarMotion.isReduced }
    /// Puts a panel on screen, once — live by default; a slide
    /// suite pins it inert so no panel flashes on the runner.
    var present: @MainActor (NSPanel) -> Void = {
        $0.orderFrontRegardless()
    }
    /// The WindowServer stack, window number to its index front
    /// first — one read per press; pinned empty by `makeTestCore`.
    var stackOrder: @MainActor () -> [UInt32: Int] = {
        let list =
            CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]] ?? []
        var order: [UInt32: Int] = [:]
        for (index, info) in list.enumerated() {
            if let number = info[kCGWindowNumber as String] as? UInt32 {
                order[number] = index
            }
        }
        return order
    }
    /// An app's icon by pid.
    var icon: @MainActor (pid_t) -> NSImage? = {
        NSRunningApplication(processIdentifier: $0)?.icon
    }
    /// The render-server clock every time here is measured on.
    var clock: @MainActor () -> CFTimeInterval = { CACurrentMediaTime() }

    /// One switch's request: the screen it plays on, its Cocoa
    /// frame, the axis, the plates over the windows shown now and
    /// the windows that stay (sticky), both in AX coordinates.
    struct Press {
        let display: DisplayID
        let screen: CGRect
        let axis: SpaceSlidePlan.Axis
        let outgoing: [SpaceSlidePlan.Plate]
        let holes: [CGRect]
        let glass: Bool
    }

    struct Play {
        let display: DisplayID
        let panel: NSPanel
        let screen: CGRect
        let axis: SpaceSlidePlan.Axis
        let fader: CALayer
        let holeHost: NSView
        let strip: NSView
        var glass: Bool
        var pages: [CGFloat: NSView] = [:]
        var motion = SpaceSlideStrip()
        var target: CGFloat = 0
        var pressAt: CFTimeInterval = 0
        var plannedBegin: CFTimeInterval = 0
        var landAt: CFTimeInterval = 0
        var liftAt: CFTimeInterval = 0

        var pageLength: CGFloat {
            axis == .horizontal ? screen.width : screen.height
        }
    }

    private(set) var play: Play?
    private var teardown: DispatchWorkItem?

    var isPlaying: Bool { play != nil }

    /// Starts or carries on a play and covers the windows shown
    /// now; returns the render time the strip lands, which is when
    /// the incoming windows' held writes may leave.
    func press(_ press: Press) -> CFTimeInterval {
        let now = clock()
        if let play, play.display != press.display || play.axis != press.axis {
            end()
        }
        var fadeFrom: Float?
        var current: Play
        if let play {
            current = play
            current.glass = press.glass
            if now >= play.liftAt {
                fadeFrom = play.fader.presentation()?.opacity ?? 0
            }
            // Windows already landed need the park's time again;
            // ones still held never showed, so the strip goes on.
            current.plannedBegin =
                now >= play.landAt
                ? now + SpaceSlidePlan.stripDelay
                : max(now, play.motion.begin)
        } else {
            current = start(press)
            current.plannedBegin = now + SpaceSlidePlan.stripDelay
            fadeFrom = 0
        }
        current.pressAt = now
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        setHoles(press.holes, in: current)
        replacePage(at: current.target, with: press.outgoing, in: &current)
        current.fader.opacity = 1
        if let from = fadeFrom {
            current.fader.removeAnimation(forKey: "out")
            current.fader.add(
                BarMotion.slideFade(
                    from: from,
                    to: 1,
                    begin: now,
                    duration: SpaceSlidePlan.fadeIn * Double(1 - from),
                    reduceMotion: reduceMotion()
                ),
                forKey: "in"
            )
        }
        let begin =
            current.motion.retargeted(
                to: current.target,
                at: now,
                begin: current.plannedBegin
            ).begin
        current.landAt = begin + SpaceSlidePlan.settle
        current.liftAt = current.landAt + SpaceSlidePlan.landMargin
        scheduleLift(&current, now: now)
        CATransaction.commit()
        // Ahead of the retile in this same turn: the fade must not
        // wait for the switch's own main-thread work.
        CATransaction.flush()
        play = current
        return current.landAt
    }

    /// Adds the incoming page one page toward `direction` (+1:
    /// from the trailing side) and runs the strip there from where
    /// it is, at the speed it has.
    func run(
        incoming: [SpaceSlidePlan.Plate],
        direction: CGFloat,
        holes: [CGRect]
    ) {
        guard var current = play else { return }
        let page = current.target + direction * current.pageLength
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        setHoles(holes, in: current)
        replacePage(at: page, with: incoming, in: &current)
        current.motion = current.motion.retargeted(
            to: page,
            at: current.pressAt,
            begin: current.plannedBegin
        )
        current.target = page
        let keyPath = Self.keyPath(current.axis)
        let layer = current.strip.layer
        layer?.setValue(
            Self.translation(page, current.axis),
            forKeyPath: keyPath
        )
        layer?.removeAnimation(forKey: "strip")
        layer?.add(
            BarMotion.slideSpring(
                keyPath: keyPath,
                strip: Self.translated(current.motion, current.axis),
                reduceMotion: reduceMotion()
            ),
            forKey: "strip"
        )
        CATransaction.commit()
        CATransaction.flush()
        play = current
    }

    /// Drops the play at once and leaves the panel dormant.
    func end() {
        teardown?.cancel()
        teardown = nil
        guard let current = play else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        current.fader.removeAllAnimations()
        current.fader.opacity = 0
        current.strip.layer?.removeAllAnimations()
        current.strip.layer?.setValue(
            0,
            forKeyPath: Self.keyPath(current.axis)
        )
        for page in current.pages.values { page.removeFromSuperview() }
        current.holeHost.layer?.mask = nil
        CATransaction.commit()
        play = nil
    }

    private func scheduleLift(_ current: inout Play, now: CFTimeInterval) {
        current.fader.add(
            BarMotion.slideFade(
                from: 1,
                to: 0,
                begin: current.liftAt,
                duration: SpaceSlidePlan.fadeOut,
                reduceMotion: reduceMotion()
            ),
            forKey: "out"
        )
        teardown?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.end() }
        teardown = item
        let idle = current.liftAt + SpaceSlidePlan.fadeOut - now + 0.05
        DispatchQueue.main.asyncAfter(
            deadline: .now() + max(idle, 0),
            execute: item
        )
    }

    /// A fresh play on `press.display`'s panel, ordering the panel
    /// in the first time only.
    private func start(_ press: Press) -> Play {
        let panel = panels[press.display] ?? Self.makePanel()
        panels[press.display] = panel
        if panel.frame != press.screen {
            panel.setFrame(press.screen, display: false)
        }
        let bounds = CGRect(origin: .zero, size: press.screen.size)
        let root = NSView(frame: bounds)
        root.wantsLayer = true
        root.layer?.opacity = 0
        let holeHost = NSView(frame: bounds)
        holeHost.wantsLayer = true
        root.addSubview(holeHost)
        let strip = NSView(frame: bounds)
        strip.wantsLayer = true
        holeHost.addSubview(strip)
        panel.contentView = root
        if !panel.isVisible { present(panel) }
        return Play(
            display: press.display,
            panel: panel,
            screen: press.screen,
            axis: press.axis,
            fader: root.layer ?? CALayer(),
            holeHost: holeHost,
            strip: strip,
            glass: press.glass
        )
    }

    /// The sticky windows stay on screen above the plates: a hole
    /// in the strip's host, fixed to the screen while it moves.
    private func setHoles(_ holes: [CGRect], in current: Play) {
        guard !holes.isEmpty else {
            current.holeHost.layer?.mask = nil
            return
        }
        let bounds = current.holeHost.bounds
        let path = CGMutablePath()
        path.addRect(bounds)
        for hole in holes { path.addRect(local(hole, in: current)) }
        let mask = CAShapeLayer()
        mask.frame = bounds
        mask.path = path
        mask.fillRule = .evenOdd
        current.holeHost.layer?.mask = mask
    }

    private func replacePage(
        at offset: CGFloat,
        with plates: [SpaceSlidePlan.Plate],
        in current: inout Play
    ) {
        current.pages[offset]?.removeFromSuperview()
        let page = pageView(plates, at: offset, in: current)
        current.strip.addSubview(page)
        current.pages[offset] = page
    }

    /// A page's place in the strip: across to the right, or down
    /// for a side bar — the later Space follows on.
    static func pageOrigin(_ offset: CGFloat, _ axis: SpaceSlidePlan.Axis)
        -> CGPoint
    {
        axis == .horizontal
            ? CGPoint(x: offset, y: 0) : CGPoint(x: 0, y: -offset)
    }

    static func keyPath(_ axis: SpaceSlidePlan.Axis) -> String {
        axis == .horizontal
            ? "transform.translation.x" : "transform.translation.y"
    }

    /// The strip's translation that shows the page at `offset`.
    static func translation(
        _ offset: CGFloat,
        _ axis: SpaceSlidePlan.Axis
    ) -> CGFloat {
        axis == .horizontal ? -offset : offset
    }

    static func translated(
        _ motion: SpaceSlideStrip,
        _ axis: SpaceSlidePlan.Axis
    ) -> SpaceSlideStrip {
        let sign: CGFloat = axis == .horizontal ? -1 : 1
        return SpaceSlideStrip(
            from: sign * motion.from,
            to: sign * motion.to,
            velocity: sign * motion.velocity,
            begin: motion.begin
        )
    }

    /// `rect` (AX) in the panel's own coordinates.
    func local(_ rect: CGRect, in current: Play) -> CGRect {
        GeometryUtils.flip(rect, primaryHeight: GeometryUtils.primaryHeight)
            .offsetBy(dx: -current.screen.minX, dy: -current.screen.minY)
    }

    private static func makePanel() -> NSPanel {
        let panel = BarPanel.makeNonActivating()
        panel.level = NSWindow.Level(rawValue: BarPanel.level.rawValue - 1)
        panel.ignoresMouseEvents = true
        // On every Desktop, since it is ordered in once and stays.
        panel.collectionBehavior = [
            .transient, .ignoresCycle, .canJoinAllSpaces, .stationary,
        ]
        return panel
    }
}
