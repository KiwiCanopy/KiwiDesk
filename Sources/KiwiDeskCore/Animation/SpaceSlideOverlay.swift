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
    var panels: [DisplayID: NSPanel] = [:]

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
    /// An app's icon by pid, from the one cache the bars share.
    var icon: @MainActor (pid_t) -> NSImage? = {
        BarIconCache.icon(pid: $0)
    }
    /// The render-server clock every time here is measured on.
    var clock: @MainActor () -> CFTimeInterval = { CACurrentMediaTime() }

    /// One switch's request: the screen it plays on, its Cocoa
    /// frame, the axis and direction (+1: the new page enters from
    /// the trailing side), the plates over the windows shown now,
    /// the windows that stay (sticky) — both in AX coordinates —
    /// the Space the screen will show, and the pace the strip and
    /// fades play at (`AnimationSettings.spaceSlidePace`, #1931).
    struct Press {
        let display: DisplayID
        let screen: CGRect
        let axis: SpaceSlidePlan.Axis
        let direction: CGFloat
        let outgoing: [SpaceSlidePlan.Plate]
        let holes: [CGRect]
        let space: SpaceID
        let glass: Bool
        let pace: Double
    }

    /// What a press decided: when the strip lands, and whether it
    /// dropped a play on another screen, whose holds the caller
    /// then releases.
    struct Pressed {
        let landAt: CFTimeInterval
        let dropped: Bool
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
        var pace: Double
        var pages: [CGFloat: NSView] = [:]
        var motion = SpaceSlideStrip()
        var target: CGFloat = 0
        /// The Space the play lands on; a screen showing another
        /// has been switched past it.
        var space: SpaceID
        /// The windows the last incoming page plates.
        var incoming: [WindowID] = []
        var landAt: CFTimeInterval = 0
        var liftAt: CFTimeInterval = 0

        var pageLength: CGFloat {
            axis == .horizontal ? screen.width : screen.height
        }
    }

    private(set) var play: Play?
    private var teardown: DispatchWorkItem?

    var isPlaying: Bool { play != nil }

    /// Starts or carries on a play: covers the windows shown now
    /// and decides the strip's whole motion toward the new page —
    /// the landing the held writes wait for is read off it.
    func press(_ press: Press) -> Pressed {
        let now = clock()
        var dropped = false
        if let play,
            play.display != press.display || play.axis != press.axis
        {
            end()
            dropped = true
        }
        var fadeFrom: Float?
        var current: Play
        var planned: CFTimeInterval
        if let play {
            current = play
            current.glass = press.glass
            current.pace = press.pace
            if now >= play.liftAt {
                fadeFrom = play.fader.presentation()?.opacity ?? 0
            }
            if now >= play.landAt {
                // Landed windows need the park's time again: the
                // strip rests where it is and waits for them.
                let rest = play.motion.state(at: now).offset
                current.motion = SpaceSlideStrip(
                    from: rest,
                    to: rest,
                    velocity: 0,
                    begin: now
                )
                planned = now + SpaceSlidePlan.stripDelay
            } else {
                // Held windows never showed: the strip goes on.
                planned = max(now, play.motion.begin)
            }
        } else {
            current = start(press)
            planned = now + SpaceSlidePlan.stripDelay
            fadeFrom = 0
        }
        let outgoing = current.target
        let page = outgoing + press.direction * current.pageLength
        current.motion = current.motion.retargeted(
            to: page,
            at: now,
            begin: planned,
            response: SpaceSlidePlan.response(at: current.pace)
        )
        current.target = page
        current.space = press.space
        current.landAt = current.motion.begin + current.motion.settleTime()
        current.liftAt = current.landAt + SpaceSlidePlan.landMargin
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        setHoles(press.holes, in: current)
        replacePage(at: outgoing, with: press.outgoing, in: &current)
        current.fader.opacity = 1
        if let from = fadeFrom {
            current.fader.removeAnimation(forKey: "out")
            current.fader.add(
                BarMotion.slideFade(
                    from: from,
                    to: 1,
                    begin: now,
                    duration: SpaceSlidePlan.fadeIn(at: current.pace)
                        * Double(1 - from),
                    reduceMotion: reduceMotion()
                ),
                forKey: "in"
            )
        }
        scheduleLift(&current, now: now)
        CATransaction.commit()
        // Ahead of the retile in this same turn: the fade must not
        // wait for the switch's own main-thread work.
        CATransaction.flush()
        play = current
        return Pressed(landAt: current.landAt, dropped: dropped)
    }

    /// Adds the incoming page where the press aimed the strip and
    /// runs the motion the press decided.
    func run(incoming: [SpaceSlidePlan.Plate], holes: [CGRect]) {
        guard var current = play else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        setHoles(holes, in: current)
        replacePage(at: current.target, with: incoming, in: &current)
        current.incoming = incoming.map(\.id)
        prunePages(&current)
        let keyPath = Self.keyPath(current.axis)
        let layer = current.strip.layer
        layer?.setValue(
            Self.translation(current.target, current.axis),
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
                duration: SpaceSlidePlan.fadeOut(at: current.pace),
                reduceMotion: reduceMotion()
            ),
            forKey: "out"
        )
        teardown?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.end() }
        teardown = item
        let fadeOut = SpaceSlidePlan.fadeOut(at: current.pace)
        let idle = current.liftAt + fadeOut - now + 0.05
        DispatchQueue.main.asyncAfter(
            deadline: .now() + max(idle, 0),
            execute: item
        )
    }
}
