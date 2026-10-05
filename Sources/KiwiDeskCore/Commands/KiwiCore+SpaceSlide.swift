import AppKit
import Foundation

/// Which screen an explicit switch changes, and the Space it
/// leaves there — read BEFORE the switch activates its target.
struct SpaceSlideIntent: Equatable {
    let display: DisplayID
    let leaving: SpaceID?
}

/// The plate slide's place in an explicit Space switch (#1956):
/// plates cover the windows shown now, those park AT the press,
/// the strip runs, and the incoming windows' writes are held until
/// it lands. One AX write per window, as the instant switch.
extension KiwiCore {
    /// The slide a switch to `target` would play; nil where its
    /// screen already shows it, so nothing parks.
    func spaceSlideIntent(to target: SpaceID) -> SpaceSlideIntent? {
        guard let display = state.workspaces.display(of: target)
        else { return nil }
        let leaving = state.workspaces.activeSpace(on: display)
        guard leaving != target else { return nil }
        return SpaceSlideIntent(display: display, leaving: leaving)
    }

    /// Off, or Reduce Motion: the instant switch.
    var spaceSlideStandsDown: Bool {
        !tiler.settings.animations.onSpaceChange
            || spaceSlide.reduceMotion()
    }

    /// Starts the slide ahead of the switch's one retile: covers
    /// what the screen shows, decides the strip's motion and holds
    /// the incoming windows' writes until it lands. Nil where it
    /// stands down, and the switch is instant.
    func prepareSpaceSlide(_ intent: SpaceSlideIntent) -> SpaceSlideRun? {
        guard !spaceSlideStandsDown,
            let target = state.workspaces.activeSpace,
            let screen = screen(for: intent.display)
        else { return nil }
        // The one stack read, at the press: parking moves frames
        // and never restacks, so it answers both directions.
        let stack = spaceSlide.stackOrder()
        let page = GeometryUtils.flip(
            screen.frame,
            primaryHeight: GeometryUtils.primaryHeight
        )
        // A window the switch filed into the target while it is
        // still on screen — a follow's moved window, a launch's
        // new one — goes with the user: neither covered nor held.
        let (shown, incoming) = slideMembers(of: target).partitioned {
            SpaceSlidePlan.shows(sentFrame($0.id) ?? $0.frame, on: page)
        }
        let holes = stickyHoles(on: intent.display, in: page)
        let glass = LiquidGlassGate.rendered(
            glass: tiler.settings.spaceSwitchLiquidGlass
        )
        let pressed = spaceSlide.press(
            SpaceSlideOverlay.Press(
                display: intent.display,
                screen: screen.frame,
                axis: SpaceSlidePlan.axis(
                    spaceBarEdge: tiler.settings.spaceBarStyle.edge
                ),
                direction: SpaceSlidePlan.direction(
                    from: intent.leaving,
                    to: target,
                    order: state.workspaces.order
                ),
                outgoing: intent.leaving.map {
                    slidePlates(of: $0, stack: stack, in: page)
                } ?? [],
                holes: holes,
                holding: Set(incoming.map(\.id)),
                glass: glass
            )
        )
        tiler.applier.releaseHolds(pressed.released)
        let wait = max(pressed.landAt - spaceSlide.clock(), 0)
        tiler.applier.holdWrites(incoming.map(\.id), until: .now() + wait)
        return SpaceSlideRun(
            target: target,
            display: intent.display,
            page: page,
            stack: stack,
            holes: holes,
            goesAlong: Set(shown.map(\.id))
        )
    }

    /// Runs the strip once the switch's retile has sent the
    /// incoming frames, which the incoming page is built from.
    func runSpaceSlide(_ run: SpaceSlideRun) {
        spaceSlide.run(
            incoming: slidePlates(
                of: run.target,
                stack: run.stack,
                in: run.page
            ).filter { !run.goesAlong.contains($0.id) },
            holes: run.holes
                + stickyHoles(on: run.display, in: run.page)
        )
    }

    /// Ends a play an instant switch overtakes, releasing the
    /// writes it held.
    func endSpaceSlide() {
        guard spaceSlide.isPlaying else { return }
        tiler.applier.releaseHolds(spaceSlide.end())
    }

    /// `space`'s plates on `page`, from the frames last sent —
    /// a burst's held windows never showed theirs.
    func slidePlates(
        of space: SpaceID,
        stack: [UInt32: Int],
        in page: CGRect
    ) -> [SpaceSlidePlan.Plate] {
        let mode = state.workspaces[space]?.mode
        return SpaceSlidePlan.plates(
            slideMembers(of: space).map {
                SpaceSlidePlan.Entry(
                    id: $0.id,
                    frame: sentFrame($0.id) ?? $0.frame,
                    pid: $0.pid,
                    floats: EffectiveFloat.applies(
                        isFloating: $0.isFloating,
                        mode: mode
                    )
                )
            },
            focus: state.workspaces[space]?.focused,
            stack: stack,
            in: page
        )
    }

    /// The frame last sent to `id`; a burst's held window never
    /// showed it.
    private func sentFrame(_ id: WindowID) -> CGRect? {
        tiler.commandedFrame(of: id)
    }

    /// The members a slide moves: a window the stash keeps on
    /// screen (#445) stays put, and a full-screen one is on its
    /// own Desktop.
    private func slideMembers(of space: SpaceID) -> [ManagedWindow] {
        (state.workspaces[space]?.windows ?? []).compactMap {
            state.windows[$0]
        }.filter {
            !$0.isFullscreen
                && !state.stickyExemptFromStash($0, onSpace: space)
        }
    }

    /// The sticky windows the screen renders through the switch,
    /// from the render verdict (#1225), where they are and where
    /// the switch sent them; the plates leave them uncovered.
    private func stickyHoles(
        on display: DisplayID,
        in page: CGRect
    ) -> [CGRect] {
        state.windows.all.flatMap { window -> [CGRect] in
            guard !window.isFullscreen,
                let shown = state.stickyRenderSpace(of: window),
                state.workspaces.display(of: shown) == display
            else { return [] }
            return [window.frame, sentFrame(window.id)]
                .compactMap { $0 }
                .filter { $0.intersects(page) }
        }
    }
}

/// What a prepared slide needs once the switch's retile ran.
struct SpaceSlideRun {
    let target: SpaceID
    let display: DisplayID
    let page: CGRect
    let stack: [UInt32: Int]
    let holes: [CGRect]
    /// Target members already on screen at the press: they move
    /// with the user, so no plate and no hold.
    let goesAlong: Set<WindowID>
}

extension Array {
    /// The elements `isIn` accepts, then the rest, each in order.
    fileprivate func partitioned(
        by isIn: (Element) -> Bool
    ) -> ([Element], [Element]) {
        var yes: [Element] = []
        var no: [Element] = []
        for element in self {
            if isIn(element) {
                yes.append(element)
            } else {
                no.append(element)
            }
        }
        return (yes, no)
    }
}
