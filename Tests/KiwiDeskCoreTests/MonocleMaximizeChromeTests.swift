import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The ring and the marks step aside on a maximizing Monocle's tiled
/// members through `KiwiCore.maximizesWindows(of:)` (#2976), each case
/// beside a control that differs only in the setting, or in the mode;
/// a full Maximize joins the same set (`screenFillers(of:)`).
@Suite("Monocle maximize windows: ring and marks (#2976)", .serialized)
@MainActor
struct MonocleMaximizeChromeTests {
    private static let screen = CGRect(
        x: 0,
        y: 0,
        width: 1440,
        height: 900
    )
    private let first = WindowID(1)
    private let second = WindowID(2)

    /// Two tiled windows on one Space laid out in `mode`, the first
    /// focused and sticky, "Maximize windows" as `maximize` says.
    private func makeCore(
        maximize: Bool,
        mode: String = "monocle"
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-monocle-max-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in Self.screen }
        core.tiler.allScreenFrames = { [Self.screen] }
        for (id, pid) in [(first, 900_101), (second, 900_102)] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: id,
                        pid: pid_t(pid),
                        appName: "App\(pid)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: first)!
        core.execute(
            "set_mode",
            args: [.string(space.description), .string(mode)]
        )
        core.state.workspaces.focus(first, in: space)
        core.state.setSticky(first, .global)
        core.tiler.settings.monocle.maximizeWindows = maximize
        return core
    }

    @Test("The focused member wears no ring while Monocle maximizes")
    func ringStepsAside() {
        let on = makeCore(maximize: true)
        #expect(!on.desiredBorderSpecs().contains { $0.window == first })
        let off = makeCore(maximize: false)
        #expect(off.desiredBorderSpecs().contains { $0.window == first })
    }

    @Test("Another layout keeps its ring whatever the setting")
    func otherLayoutKeepsTheRing() {
        let core = makeCore(maximize: true, mode: "bsp")
        #expect(
            core.desiredBorderSpecs().contains { $0.window == first }
        )
    }

    @Test("A member's mark steps aside while Monocle maximizes")
    func markStepsAside() {
        let on = makeCore(maximize: true)
        #expect(!on.stickyMarkSpecs().contains { $0.window == first })
        let off = makeCore(maximize: false)
        #expect(off.stickyMarkSpecs().contains { $0.window == first })
    }

    @Test("A full Maximize drops the mark; a Height one keeps it")
    func fullMaximizeDropsTheMark() {
        let full = makeCore(maximize: false, mode: "bsp")
        #expect(full.stickyMarkSpecs().contains { $0.window == first })
        #expect(full.execute("toggle_maximized").isSuccess)
        #expect(!full.stickyMarkSpecs().contains { $0.window == first })
        let height = makeCore(maximize: false, mode: "bsp")
        height.execute("toggle_maximized", args: [.string("height")])
        #expect(height.stickyMarkSpecs().contains { $0.window == first })
    }

    @Test("The predicate is no Maximize verdict")
    func predicateIsNoMaximize() throws {
        let core = makeCore(maximize: true)
        let space = try #require(core.state.workspaces.space(of: first))
        let model = try #require(core.state.workspaces[space])
        #expect(core.maximizesWindows(of: model))
        #expect(core.state.maximizedWindow(of: model) == nil)
    }
}
