import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The scroll step and the keys read their own picks (#2971): one
/// Space step, two doors, driven through the real gesture handler
/// and the real `focus_space_next`. An extension of this suite, as
/// its fixture holds the panel and the frame clock.
extension SpaceSlideSwitchTests {
    private func swipe(_ core: KiwiCore, on display: DisplayID) {
        let session = ScrollSpaceStepSession()
        session.displayAt = { _ in display }
        func event(
            _ kind: ScrollGestureEvent.Kind,
            dx: Double = 0
        ) -> ScrollGestureEvent {
            ScrollGestureEvent(
                chord: [.control, .option, .command],
                kind: kind,
                input: .trackpad,
                delta: CGVector(dx: dx, dy: 0),
                momentum: false,
                location: .zero,
                time: 0
            )
        }
        core.handleScrollSpaceStep(event(.began), session: session)
        core.handleScrollSpaceStep(event(.changed, dx: -40), session: session)
        core.handleScrollSpaceStep(event(.ended), session: session)
    }

    @Test(
        "None on the keys, Slide on the scroll step",
        .enabled(if: NSScreen.main != nil)
    )
    func scrollSlidesWhileKeysAreInstant() throws {
        let (core, _) = try makeCore(slide: true)
        let display = try #require(NSScreen.main?.kiwiDisplayID)
        core.setAppWide(persisting: false) {
            $0.spaceTransition = .none
            $0.spaceScrollTransition = .slide
        }
        swipe(core, on: display)
        defer { core.spaceSlide.end() }
        #expect(core.state.workspaces.activeSpace == SpaceID(2))
        #expect(core.spaceSlide.isPlaying)
        core.spaceSlide.end()
        core.execute("focus_space_previous")
        #expect(core.state.workspaces.activeSpace == SpaceID(1))
        #expect(!core.spaceSlide.isPlaying)
    }

    @Test(
        "Slide on the keys, None on the scroll step",
        .enabled(if: NSScreen.main != nil)
    )
    func keysSlideWhileScrollIsInstant() throws {
        let (core, _) = try makeCore(slide: true)
        let display = try #require(NSScreen.main?.kiwiDisplayID)
        core.setAppWide(persisting: false) {
            $0.spaceTransition = .slide
            $0.spaceScrollTransition = .none
        }
        swipe(core, on: display)
        defer { core.spaceSlide.end() }
        #expect(core.state.workspaces.activeSpace == SpaceID(2))
        #expect(!core.spaceSlide.isPlaying)
        core.execute("focus_space_previous")
        #expect(core.state.workspaces.activeSpace == SpaceID(1))
        #expect(core.spaceSlide.isPlaying)
    }
}
