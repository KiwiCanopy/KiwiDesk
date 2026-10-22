import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The readers of a drawn run (#2235): the visibility verdict
/// `list_windows` and the App Bar share (#2547), and the weight
/// resize inside a run. `.enabled(if:)` because the verdict
/// resolves the Space's screen.
@Suite(
    "Run readers (#2235, #2547)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct RunReadersTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-run-readers-\(UUID().uuidString)"
                )
        )
        // Pinned (tests.md, #531): whether the stack overflows is
        // what the suite reads.
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 800)
        }
        return core
    }

    /// Six windows in one stack Space, focus on window 2: the run
    /// shows windows 2 and 3, and 4…6 wait behind window 3.
    private func makeSpace(_ core: KiwiCore) -> SpaceID {
        for id in 1...6 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(900_000 + id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        _ = core.execute(
            "set_mode",
            args: [.string(space.raw), .string("stack")]
        )
        _ = core.execute("set_min_window_size", args: [.number(300)])
        core.state.workspaces.focus(WindowID(2), in: space)
        core.retile(animated: false)
        return space
    }

    @Test("A shown edge window reads visible, its hidden ones hidden")
    func visibilityReadsTheRun() throws {
        let core = makeCore()
        let id = makeSpace(core)
        let space = try #require(core.state.workspaces[id])
        let placements = core.windowPlacements(of: space, floats: [])
        // Window 3 is the edge slot the hidden ones share; it is
        // not focused, which is #2547's case.
        #expect(placements[WindowID(3)]?.visibility == .visible)
        for hidden in 4...6 {
            #expect(
                placements[WindowID(UInt32(hidden))]?.visibility
                    == .hidden
            )
        }
        #expect(placements[WindowID(2)]?.visibility == .visible)
    }

    @Test("A weight press in a run divides the span its floors leave")
    func resizeInRunWrites() throws {
        let core = makeCore()
        let id = makeSpace(core)
        let space = try #require(core.state.workspaces[id])
        let run = try #require(
            core.tiler.runCovers[id]?.runs.first {
                $0.shown.contains(WindowID(2))
            }
        )
        #expect(Array(run.shown) == [WindowID(2), WindowID(3)])
        #expect(run.extra > 0)
        // The run's step: the shown pair over the span their
        // floors leave, with no minimum of its own.
        let expected = StackLayout.weightStep(
            weights: [1, 1],
            at: 0,
            delta: 50,
            span: Double(run.extra),
            minSizes: [0, 0]
        ).value
        // The whole-zone step the run replaced divides the full
        // span over every member, which lands elsewhere.
        let wholeZone = StackLayout.weightStep(
            weights: [1, 1, 1, 1, 1],
            at: 0,
            delta: 50,
            span: 780,
            minSizes: Array(repeating: 300, count: 5)
        ).value
        #expect(abs(expected - wholeZone) > 0.01)
        let response = core.resizeStackMember(
            WindowID(2),
            axis: "y",
            delta: 50,
            span: 780,
            space: space
        )
        #expect(response.isSuccess)
        let weight = try #require(
            core.state.workspaces[id]?.stackWeights[WindowID(2)]
        )
        #expect(abs(weight - expected) < 0.0001)
    }
}
