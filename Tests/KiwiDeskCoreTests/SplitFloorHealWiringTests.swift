import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The split floor heal's wiring over a real core (#934/#1430):
/// the retile moves a bsp split ratio or the stack master ratio
/// so a side draws its learned floor, idempotently, standing down
/// on a forced pass and never for a traveler. The math is
/// `SplitFloorHealTests`, the cue `SplitFloorCueTests`. Display
/// and `min_window_size` pinned (#531, #660).
@Suite("Split floor heal wiring (#934)", .serialized)
@MainActor
struct SplitFloorHealWiringTests {
    /// `count` windows on a pinned 1200×800 display, in `mode`.
    private func makeCore(
        windows count: Int,
        mode: String
    ) -> (KiwiCore, SpaceID) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-split-heal-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        #expect(core.tiler.settings.minWindowSize == 300)
        for id in 1...count {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string(mode)]
        )
        core.state.workspaces.focus(WindowID(1), in: space)
        return (core, space)
    }

    /// Teaches a corroborated floor on one axis: two distinct
    /// asks, each refused twice with the same answer (the ladder
    /// itself is `SizeBoundLearnerTests`; this is the wire).
    private func seed(
        _ core: KiwiCore,
        window: WindowID,
        minWidth: CGFloat? = nil,
        minHeight: CGFloat? = nil
    ) {
        let width = minWidth ?? 585
        let height = minHeight ?? 385
        for step in [CGFloat(60), CGFloat(110)] {
            for _ in 0..<2 {
                core.tiler.boundLearner.recordAsk(
                    window,
                    size: CGSize(
                        width: minWidth == nil ? width : width - step,
                        height: minHeight == nil
                            ? height : height - step
                    )
                )
                core.tiler.boundLearner.observe(
                    window,
                    currentSize: CGSize(width: width, height: height),
                    settledRead: true
                )
            }
        }
    }

    private func ratioH(_ core: KiwiCore, _ space: SpaceID) -> Double {
        core.tiler.settings.resolvedBsp(
            for: core.state.workspaces[space]!
        ).splitRatioH
    }

    @Test("A bsp retile moves the horizontal ratio to a learned floor")
    func bspHealsTheHorizontalRatio() throws {
        guard NSScreen.main != nil else { return }
        let (core, space) = makeCore(windows: 2, mode: "bsp")
        let w2 = WindowID(2)
        seed(core, window: w2, minWidth: 700)
        #expect(core.tiler.sizeBound(for: w2)?.minWidth == 700)
        #expect(ratioH(core, space) == 0.5)
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.retile()
        #expect(log.contains { $0.contains("split ratio healed") })
        // 1170 pt split: the right side draws 700.25.
        let healed = ratioH(core, space)
        #expect(abs((1 - healed) * 1170 - 700.25) < 0.01)
        let frame = try #require(
            core.tiler.calculatedFrames(state: core.state)[w2]
        )
        #expect(frame.width >= 700)
        // Idempotent: the next retile finds the floor drawn and
        // rewrites nothing.
        log.removeAll()
        core.retile()
        #expect(ratioH(core, space) == healed)
        #expect(!log.contains { $0.contains("split ratio healed") })
    }

    @Test("A bsp retile moves the vertical ratio for a stacked split")
    func bspHealsTheVerticalRatio() throws {
        guard NSScreen.main != nil else { return }
        // Three windows: the right half stacks w2 over w3 on the
        // vertical ratio (alternating dwindle).
        let (core, space) = makeCore(windows: 3, mode: "bsp")
        let w3 = WindowID(3)
        seed(core, window: w3, minHeight: 400)
        #expect(core.tiler.sizeBound(for: w3)?.minHeight == 400)
        // The stacked span the layout divides, read off the same
        // authorities the heal reads: the region less the Space
        // Bar's default strip (#660 — pinned, since the fixture
        // reasons from it), the outer gaps and the inner gap.
        let screen = try #require(NSScreen.main)
        let bounds = core.tiler.layoutBounds(
            on: screen,
            for: try #require(core.state.workspaces[space])
        )
        let gaps = core.tiler.settings.gaps(for: space)
        let span =
            bounds.height - gaps.outer.top - gaps.outer.bottom
            - gaps.inner.vertical
        #expect(span == 730)
        core.retile()
        let bsp = core.tiler.settings.resolvedBsp(
            for: core.state.workspaces[space]!
        )
        // The bottom draws 400.25; the horizontal ratio, which
        // no floor binds, stays.
        #expect(abs((1 - bsp.splitRatioV) * span - 400.25) < 0.01)
        #expect(bsp.splitRatioH == 0.5)
        let frame = try #require(
            core.tiler.calculatedFrames(state: core.state)[w3]
        )
        #expect(frame.height >= 400)
    }

    @Test("A stack retile moves the master ratio to a learned floor")
    func stackHealsTheMasterRatio() throws {
        guard NSScreen.main != nil else { return }
        let (core, space) = makeCore(windows: 2, mode: "stack")
        let w2 = WindowID(2)
        seed(core, window: w2, minWidth: 700)
        core.retile()
        let ratio = core.tiler.settings.resolvedStack(
            for: core.state.workspaces[space]!
        ).masterRatio
        // 1170 pt split: the stack zone draws 700.25.
        #expect(abs((1 - ratio) * 1170 - 700.25) < 0.01)
        let frame = try #require(
            core.tiler.calculatedFrames(state: core.state)[w2]
        )
        #expect(frame.width >= 700)
    }

    @Test("A forced pass stands the heal down")
    func forcedPassStandsDown() {
        guard NSScreen.main != nil else { return }
        let (core, space) = makeCore(windows: 2, mode: "bsp")
        seed(core, window: WindowID(2), minWidth: 700)
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.retile(pass: .apply)
        #expect(ratioH(core, space) == 0.5)
        #expect(!log.contains { $0.contains("split ratio healed") })
        // The next ordinary pass heals.
        core.retile()
        #expect(ratioH(core, space) < 0.5)
    }

    @Test("A visiting traveler's floor never moves a stored ratio")
    func travelerNeverHeals() {
        guard NSScreen.main != nil else { return }
        let (core, space) = makeCore(windows: 2, mode: "bsp")
        seed(core, window: WindowID(2), minWidth: 700)
        core.retile()
        let healed = ratioH(core, space)
        #expect(healed < 0.5)
        // A tiled-sticky window homed on ANOTHER space: the
        // active space's effective members inject it (#414 v2),
        // the local members do not — pin the divergence, or this
        // test discriminates nothing.
        core.state.windows.upsert(
            ManagedWindow(
                id: WindowID(9),
                pid: 9,
                appName: "Visitor",
                stickyScope: .global
            )
        )
        core.state.workspaces.add(WindowID(9), to: SpaceID("2"))
        let s1 = core.state.workspaces[space]!
        #expect(
            core.state.effectiveTiledMembers(of: s1)
                .contains(WindowID(9))
        )
        #expect(
            !core.state.localTiledMembers(of: s1).contains(WindowID(9))
        )
        // A floor the split can never fit beside w2's: healed
        // against the effective list this would cue the unfit
        // pill; against the local list nothing sinks.
        seed(core, window: WindowID(9), minWidth: 900)
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.retile()
        #expect(ratioH(core, space) == healed)
        #expect(refusals.isEmpty)
        #expect(!log.contains { $0.contains("split floor unfit") })
    }
}
