import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The readers ruled onto the one presenting door (#1788): a
/// float covering its whole screen is a slide show, so it wears
/// no ring and no mark, and its first focus is never read as an
/// app answering our placement. Each case beside a control that
/// differs only in the frame, and a tiled window covering the
/// screen — a gapless layout's slot — is no presentation.
@Suite("Presenting readers (#1788)", .serialized)
@MainActor
struct PresentingReaderTests {
    private static let screen = CGRect(
        x: 0,
        y: 0,
        width: 1440,
        height: 900
    )
    private static let small = CGRect(
        x: 200,
        y: 200,
        width: 600,
        height: 400
    )
    private let show = WindowID(1)
    private let editor = WindowID(2)

    /// The show (flag-floating at `frame`) beside a tiled editor
    /// on one space, the show focused.
    private func makeCore(
        frame: CGRect,
        floating: Bool = true
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-presenting-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in Self.screen }
        core.tiler.allScreenFrames = { [Self.screen] }
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: show,
                    pid: 1,
                    appName: "Slides",
                    frame: frame,
                    isFloating: floating
                )
            )
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: editor,
                    pid: 2,
                    appName: "Editor",
                    frame: Self.small
                )
            )
        )
        let space = core.state.workspaces.space(of: show)!
        core.state.workspaces.focus(show, in: space)
        return core
    }

    @Test("A presenting float wears no ring; a smaller one does")
    func ringStandsDown() {
        let presenting = makeCore(frame: Self.screen)
        #expect(
            !presenting.desiredBorderSpecs().contains {
                $0.window == show
            }
        )
        let control = makeCore(frame: Self.small)
        #expect(
            control.desiredBorderSpecs().contains {
                $0.window == show
            }
        )
    }

    @Test("A tiled window filling the screen keeps its ring")
    func tiledSlotIsNoPresentation() {
        let core = makeCore(frame: Self.screen, floating: false)
        #expect(!core.presents(show, at: Self.screen))
        #expect(
            core.desiredBorderSpecs().contains { $0.window == show }
        )
    }

    @Test("A presenting sticky float wears no mark")
    func markStandsDown() {
        let presenting = makeCore(frame: Self.screen)
        presenting.state.setSticky(show, .global)
        #expect(
            !presenting.stickyMarkSpecs().contains {
                $0.window == show
            }
        )
        let control = makeCore(frame: Self.small)
        control.state.setSticky(show, .global)
        #expect(
            control.stickyMarkSpecs().contains { $0.window == show }
        )
    }

    /// The scrolling arm reads the live entry alone, so without
    /// the door a window we placed small, whose app then starts
    /// its show over the whole screen, has that show's first
    /// focus bounced back to the editor. The placement stays
    /// small in both cases, so only the ACTUAL frame decides.
    @Test("A show's first focus is never a placement bounce")
    func bounceStandsDown() {
        for (frame, bounced) in [
            (Self.screen, false), (Self.small, true),
        ] {
            let core = makeCore(frame: frame)
            let space = core.state.workspaces.space(of: show)!
            _ = core.execute(
                "set_mode",
                args: [.string(space.raw), .string("scrolling")]
            )
            core.state.workspaces.focus(editor, in: space)
            core.tiler.placements.forgetAll()
            core.tiler.placements.stamp(show, target: Self.small)
            core.handle(.windowFocused(show))
            #expect(
                (core.activeSpace?.focused == editor) == bounced,
                "frame \(frame)"
            )
        }
    }

    /// A restore's echo may trail the show's focus: the state
    /// frame still small, the placement already the show's.
    @Test("A placement covering the screen is judged before its echo")
    func placedFrameIsJudged() {
        let core = makeCore(frame: Self.small)
        let space = core.state.workspaces.space(of: show)!
        _ = core.execute(
            "set_mode",
            args: [.string(space.raw), .string("scrolling")]
        )
        core.tiler.placements.forgetAll()
        core.tiler.placements.stamp(show, target: Self.screen)
        #expect(core.placementBounce(show, now: core.wallClock()) == nil)
    }

    /// A float growing into a show neither retiles nor reports a
    /// focus, so the crossing itself re-reads the ring and the
    /// mark — and the shrink back gives them back.
    @Test("A float crossing into a show drops its ring and mark")
    func crossingRefreshesRingAndMark() {
        let core = makeCore(frame: Self.small)
        core.state.setSticky(show, .global)
        core.updateBorders()
        core.updateStickyMarks()
        #expect(core.borders.specs[show] != nil)
        #expect(core.stickyMarks.overlays[show] != nil)

        core.handle(.windowResized(show, Self.screen))
        #expect(core.borders.specs[show] == nil)
        #expect(core.stickyMarks.overlays[show] == nil)

        core.handle(.windowResized(show, Self.small))
        #expect(core.borders.specs[show] != nil)
        #expect(core.stickyMarks.overlays[show] != nil)
    }
}
