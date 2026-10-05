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

    /// Plays the slide around the switch's retile into the active
    /// Space; false where it stands down, and the caller retiles
    /// instantly.
    func playSpaceSlide(
        _ intent: SpaceSlideIntent,
        arriving: WindowID?
    ) -> Bool {
        // The one stack read, at the press: parking moves frames
        // and never restacks, so it answers both directions.
        guard !spaceSlideStandsDown,
            let target = state.workspaces.activeSpace
        else { return false }
        let stack = spaceSlide.stackOrder()
        guard let press = spaceSlidePress(intent, stack: stack)
        else { return false }
        let landAt = spaceSlide.press(press)
        let incoming = slideMembers(of: target).map(\.id)
        let wait = max(landAt - spaceSlide.clock(), 0)
        tiler.applier.holdWrites(incoming, until: .now() + wait)
        retile(
            animated: false,
            pass: .reissue,
            newlyCreatedWindow: arriving
        )
        let page = press.screen.flippedToAX
        spaceSlide.run(
            incoming: slidePlates(
                of: target,
                stack: stack,
                in: page
            ),
            direction: SpaceSlidePlan.direction(
                from: intent.leaving,
                to: target,
                order: state.workspaces.order
            ),
            holes: press.holes + stickyHoles(in: page, sent: true)
        )
        return true
    }

    /// The press for `intent`: the screen, its axis and glass, and
    /// the plates over what it shows now.
    private func spaceSlidePress(
        _ intent: SpaceSlideIntent,
        stack: [UInt32: Int]
    ) -> SpaceSlideOverlay.Press? {
        guard let screen = screen(for: intent.display) else {
            return nil
        }
        let page = screen.frame.flippedToAX
        let glass = LiquidGlassGate.rendered(
            glass: tiler.settings.spaceSwitchLiquidGlass
        )
        return SpaceSlideOverlay.Press(
            display: intent.display,
            screen: screen.frame,
            axis: SpaceSlidePlan.axis(
                spaceBarEdge: tiler.settings.spaceBarStyle.edge
            ),
            outgoing: intent.leaving.map {
                slidePlates(of: $0, stack: stack, in: page)
            } ?? [],
            holes: stickyHoles(in: page, sent: false),
            glass: glass
        )
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
                    frame: tiler.commandedFrame(of: $0.id) ?? $0.frame,
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

    /// The members a slide moves: a sticky window stays on screen
    /// and a full-screen one is on its own Desktop.
    private func slideMembers(of space: SpaceID) -> [ManagedWindow] {
        (state.workspaces[space]?.windows ?? []).compactMap {
            state.windows[$0]
        }.filter { !$0.isSticky && !$0.isFullscreen }
    }

    /// The sticky windows on `page` — where they are, or where the
    /// switch just sent them — which the plates leave uncovered.
    private func stickyHoles(in page: CGRect, sent: Bool) -> [CGRect] {
        state.windows.all.compactMap { window in
            guard window.isSticky, !window.isFullscreen else {
                return nil
            }
            let frame =
                sent
                ? tiler.commandedFrame(of: window.id) ?? window.frame
                : window.frame
            return frame.intersects(page) ? frame : nil
        }
    }
}

extension CGRect {
    /// A Cocoa screen rect in AX coordinates.
    @MainActor
    fileprivate var flippedToAX: CGRect {
        GeometryUtils.flip(self, primaryHeight: GeometryUtils.primaryHeight)
    }
}
