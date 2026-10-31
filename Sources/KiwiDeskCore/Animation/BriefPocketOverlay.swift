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
        frames?.invalidate()
        for panel in panels.values { panel.orderOut(nil) }
    }

    /// The Reduce Motion read — live by default; pinned ON in both
    /// `makeTestCore` twins, so no suite plays unless it says so.
    var reduceMotion: @MainActor () -> Bool = { BarMotion.isReduced }
    /// Puts a panel on screen, once.
    var present: @MainActor (NSPanel) -> Void = {
        $0.orderFrontRegardless()
    }
    /// An app's icon by pid, from the one cache the bars share.
    var icon: @MainActor (pid_t) -> NSImage? = {
        BarIconCache.icon(pid: $0)
    }
    /// The clock every time here is measured on.
    var clock: @MainActor () -> CFTimeInterval = { CACurrentMediaTime() }
    /// Builds a play's frame clock on its screen — one
    /// `DisplayLinkDriver` per play, which reports a starved clock
    /// as every driver does (#1084).
    var makeFrames:
        @MainActor (NSScreen, @escaping DisplayLinkDriver.Tick)
            -> DisplayLinkDriver? = {
                DisplayLinkDriver(screen: $0, onTick: $1)
            }
    private var frames: DisplayLinkDriver?

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
        let markHex: String
        /// False while the pocket plate stands at the pocket (#2678):
        /// the plate flies to it, and no second pocket is drawn.
        var drawsPocket = true
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
    /// The request playing now, nil between plays.
    var playing: Request? { play?.request }

    /// Plays `request`, ending any play still running first.
    func play(_ request: Request) {
        end()
        generation += 1
        let panel = panel(for: request)
        // A tinted plate wears the key-window rim, as the Space
        // switch's plates do (#2569).
        (panel as? ActiveGlassPanel)?.wearsActiveLook =
            request.plateTint != nil
        let bounds = CGRect(origin: .zero, size: request.screen.frame.size)
        let root = AppBarOverlay.FlippedView(frame: bounds)
        root.wantsLayer = true
        let pocketHost = AppBarOverlay.FlippedView(frame: bounds)
        let plateHost = AppBarOverlay.FlippedView(frame: bounds)
        // The plate passes over the pocket going in, so it is on top.
        root.addSubview(pocketHost)
        root.addSubview(plateHost)
        let pocket = BriefPocketView(frame: .zero)
        pocket.wear(markHex: request.markHex)
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
        frames = makeFrames(request.screen) { [weak self] _ in
            self?.tick(mine)
        }
        frames?.start()
        // A screen that leaves mid-play stops its clock; the play
        // still ends on time.
        let over = current.timeline.end + 0.1
        DispatchQueue.main.asyncAfter(deadline: .now() + over) {
            [weak self] in
            guard self?.play?.generation == mine else { return }
            self?.end()
        }
    }

    /// Drops the play at once and leaves the panel empty.
    func end() {
        frames?.invalidate()
        frames = nil
        guard let current = play else { return }
        current.panel.contentView = nil
        play = nil
    }

    /// One frame of play `mine`; ends the play once it is over.
    private func tick(_ mine: Int) {
        guard let current = play, current.generation == mine
        else { return }
        let t = clock() - current.begin
        guard t < current.timeline.end else { return end() }
        draw(current, at: t)
    }

    private func draw(_ current: Play, at t: TimeInterval) {
        let request = current.request
        let timeline = current.timeline
        current.pocketHost.alphaValue =
            request.drawsPocket
            ? BriefPocketPlan.pocketOpacity(at: t, timeline: timeline) : 0
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
            ActiveGlassPanel(
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
