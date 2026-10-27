import AppKit
import QuartzCore

/// The brief pocket (#2680): while a window goes into the pocket or
/// comes out, a pocket appears at its place on the screen, a plate
/// flies between it and the window, it nods, and it fades out. A
/// picture over the windows, never an animation of them: the window
/// parks at once and comes back with one write. One panel per
/// screen, ordered in on first use and never moved; each tick of
/// that screen's `DisplayLink` redraws the pocket and the plate at
/// the size `BriefPocketPlan` gives for the moment.
@MainActor
final class BriefPocketOverlay {
    private var panels: [DisplayID: NSPanel] = [:]

    /// AppKit keeps a visible panel alive after its owner is gone
    /// (#1868).
    isolated deinit {
        for panel in panels.values { panel.orderOut(nil) }
    }

    /// Puts a panel on screen, once. Reached only by a play, which
    /// the slide's Reduce Motion read — pinned ON in both
    /// `makeTestCore` twins — keeps from every suite but the brief
    /// pocket's, which pins this and `startFrames` itself.
    var present: @MainActor (NSPanel) -> Void = {
        $0.orderFrontRegardless()
    }
    /// An app's icon by pid, from the one cache the bars share.
    var icon: @MainActor (pid_t) -> NSImage? = {
        BarIconCache.icon(pid: $0)
    }
    /// The clock every time here is measured on.
    var clock: @MainActor () -> CFTimeInterval = { CACurrentMediaTime() }
    /// Starts `screen`'s frame clock calling `tick` until it
    /// answers false — one `DisplayLink` per screen.
    var startFrames:
        @MainActor (NSScreen, @escaping @MainActor () -> Bool) -> Void = {
            BriefPocketTicker.start(on: $0, tick: $1)
        }

    /// One play: the screen (its Cocoa frame) it shows on, which
    /// way the plate flies, the window's frame and the pocket's —
    /// both AX — and how both are drawn.
    struct Request {
        let display: DisplayID
        let screen: NSScreen
        let direction: BriefPocketPlan.Direction
        let window: CGRect
        let pocket: CGRect
        let iconPid: pid_t?
        /// KiwiShelf as drawn, glass gated.
        let shelf: KiwiShelf
        let markHex: String
        /// Whether the plate draws Liquid Glass, and the Fill it
        /// wears there, nil for the untinted glass.
        let plateGlass: Bool
        let plateTint: GlassFill?
        let flight: TimeInterval
    }

    private struct Play {
        let request: Request
        let panel: NSPanel
        let root: NSView
        let pocketHost: NSView
        let pocket: BriefPocketView
        let plateHost: NSView
        let plate: BriefPocketPlateView
        let origin: CGPoint
        let begin: CFTimeInterval
        let timeline: BriefPocketPlan.Timeline
        let generation: Int
    }

    private var play: Play?
    private var generation = 0

    var isPlaying: Bool { play != nil }

    /// Plays `request`, ending any play still running first.
    func play(_ request: Request) {
        end()
        generation += 1
        let panel = panel(for: request)
        let bounds = CGRect(origin: .zero, size: request.screen.frame.size)
        let root = AppBarOverlay.FlippedView(frame: bounds)
        root.wantsLayer = true
        let pocketHost = AppBarOverlay.FlippedView(frame: bounds)
        let plateHost = AppBarOverlay.FlippedView(frame: bounds)
        // The plate passes over the pocket going in, so it is on top.
        root.addSubview(pocketHost)
        root.addSubview(plateHost)
        let pocket = BriefPocketView(frame: .zero)
        pocket.wear(request.shelf, markHex: request.markHex)
        pocketHost.addSubview(pocket)
        let plate = BriefPocketPlateView(
            glass: request.plateGlass,
            tint: request.plateTint,
            image: request.iconPid.flatMap { icon($0) }
        )
        plateHost.addSubview(plate)
        panel.contentView = root
        if !panel.isVisible { present(panel) }
        let ax = GeometryUtils.flip(
            request.screen.frame,
            primaryHeight: GeometryUtils.primaryHeight
        )
        let current = Play(
            request: request,
            panel: panel,
            root: root,
            pocketHost: pocketHost,
            pocket: pocket,
            plateHost: plateHost,
            plate: plate,
            origin: ax.origin,
            begin: clock(),
            timeline: BriefPocketPlan.timeline(
                request.direction,
                flight: request.flight
            ),
            generation: generation
        )
        play = current
        draw(current, at: 0)
        let mine = generation
        startFrames(request.screen) { [weak self] in
            self?.tick(mine) ?? false
        }
    }

    /// Drops the play at once and leaves the panel empty.
    func end() {
        guard let current = play else { return }
        current.panel.contentView = nil
        play = nil
    }

    /// One frame of play `mine`; false once it is over or replaced.
    private func tick(_ mine: Int) -> Bool {
        guard let current = play, current.generation == mine
        else { return false }
        let t = clock() - current.begin
        guard t < current.timeline.end else {
            end()
            return false
        }
        draw(current, at: t)
        return true
    }

    private func draw(_ current: Play, at t: TimeInterval) {
        let request = current.request
        let timeline = current.timeline
        current.pocketHost.alphaValue = BriefPocketPlan.pocketOpacity(
            at: t,
            timeline: timeline
        )
        current.pocket.frame = local(
            BriefPocketPlan.pocketFrame(
                request.pocket,
                at: t,
                timeline: timeline
            ),
            current
        )
        current.plateHost.alphaValue = BriefPocketPlan.plateOpacity(
            at: t,
            direction: request.direction,
            timeline: timeline
        )
        current.plate.place(
            local(
                BriefPocketPlan.plateFrame(
                    at: t,
                    direction: request.direction,
                    window: request.window,
                    pocket: request.pocket,
                    timeline: timeline
                ),
                current
            ),
            host: current.root.effectiveAppearance
        )
    }

    private func local(_ rect: CGRect, _ current: Play) -> CGRect {
        rect.offsetBy(dx: -current.origin.x, dy: -current.origin.y)
    }

    private func panel(for request: Request) -> NSPanel {
        let live = Set(ScreenList.all.compactMap(\.kiwiDisplayID))
        for (display, panel) in panels where !live.contains(display) {
            panel.orderOut(nil)
            panels[display] = nil
        }
        let panel = panels[request.display] ?? Self.makePanel()
        panels[request.display] = panel
        if panel.frame != request.screen.frame {
            panel.setFrame(request.screen.frame, display: false)
        }
        return panel
    }

    private static func makePanel() -> NSPanel {
        let panel = BarPanel.configure(
            NSPanel(
                contentRect: .zero,
                styleMask: BarPanel.styleMask,
                backing: .buffered,
                defer: true
            )
        )
        panel.level = BarPanel.level
        panel.ignoresMouseEvents = true
        // On every Desktop, since it is ordered in once and stays.
        panel.collectionBehavior = [
            .transient, .ignoresCycle, .canJoinAllSpaces, .stationary,
        ]
        return panel
    }
}

/// A screen's frame clock for the brief pocket: a `CADisplayLink`
/// from that screen, invalidated the tick its play says it is over.
@MainActor
final class BriefPocketTicker: NSObject {
    private let tick: @MainActor () -> Bool
    private var link: CADisplayLink?
    /// Live tickers; each removes itself when it stops.
    private static var running: Set<BriefPocketTicker> = []

    private init(tick: @escaping @MainActor () -> Bool) {
        self.tick = tick
    }

    static func start(
        on screen: NSScreen,
        tick: @escaping @MainActor () -> Bool
    ) {
        let ticker = BriefPocketTicker(tick: tick)
        let link = screen.displayLink(
            target: ticker,
            selector: #selector(step(_:))
        )
        ticker.link = link
        running.insert(ticker)
        link.add(to: .main, forMode: .common)
    }

    @objc private func step(_ link: CADisplayLink) {
        guard tick() else {
            link.invalidate()
            self.link = nil
            Self.running.remove(self)
            return
        }
    }
}
