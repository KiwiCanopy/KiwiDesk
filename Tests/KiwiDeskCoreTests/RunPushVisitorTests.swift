import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A window visiting a run from another Space (#2709, #308): a press
/// on it is refused and writes no entry its Space could never prune.
/// The display, gaps and floor are pinned (#531, #660);
/// `.enabled(if:)` because the writers resolve the Space's screen.
@Suite(
    "Run push visitors (#2709)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct RunPushVisitorTests {
    /// `count` windows in one `mode` Space on a 1220 × 820 display
    /// with 10-pt gaps and every bar off, `focus` focused.
    private func makeSpace(
        _ mode: String,
        windows count: UInt32,
        focus: UInt32,
        width: CGFloat = 1220,
        height: CGFloat = 820,
        setup: (KiwiCore) -> Void = { _ in }
    ) -> (KiwiCore, SpaceID) {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-run-push-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: width, height: height)
        }
        core.tiler.settings.gapsGlobal = Gaps.uniform(10)
        for verb in [
            "space_bar.set_visibility",
            "monocle.set_app_bar_visibility",
            "scroll.set_app_bar_visibility",
        ] {
            core.execute(verb, args: [.string("hidden")])
        }
        #expect(!core.tiler.settings.anyAppBarCanShow)
        #expect(
            core.tiler.settings.minWindowSizes == MinWindowSizes(all: 300)
        )
        core.tiler.animation.isEnabled = false
        core.tiler.settings.mouseResize = .layout
        setup(core)
        for id in UInt32(1)...count {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: pid_t(900_000 + Int32(id)),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute("set_mode", args: [.string(space.raw), .string(mode)])
        core.state.workspaces.focus(WindowID(focus), in: space)
        core.retile(animated: false)
        return (core, space)
    }

    private func press(
        _ core: KiwiCore,
        _ axis: String,
        _ points: Double
    ) {
        core.execute("resize", args: [.string(axis), .number(points)])
        core.retile(animated: false)
    }

    private func hidden(_ core: KiwiCore, _ id: SpaceID) -> Set<WindowID> {
        Set(core.tiler.runCovers[id]?.behind.keys.map { $0 } ?? [])
    }

    private func w(_ raw: UInt32) -> WindowID { WindowID(raw) }

    @Test("BSP: a window visiting the chain is refused, not sized")
    func visitorIsRefused() throws {
        let (core, id) = makeSpace("bsp", windows: 4, focus: 2) {
            $0.execute("bsp.set_strategy", args: [.string("alternating")])
        }
        core.state.workspaces.ensureSpace(SpaceID("2"))
        // Three home-mates ahead of it, so the traveler is injected
        // at index 3, inside the chain.
        for id: UInt32 in 60...62 {
            core.state.windows.upsert(
                ManagedWindow(id: w(id), pid: 900_060, appName: "H")
            )
            core.state.workspaces.add(w(id), to: SpaceID("2"))
        }
        core.state.windows.upsert(
            ManagedWindow(
                id: w(50),
                pid: 900_050,
                appName: "Traveler",
                stickyScope: .global
            )
        )
        core.state.workspaces.add(w(50), to: SpaceID("2"))
        core.retile(animated: false)
        let space = try #require(core.state.workspaces[id])
        #expect(!space.windows.contains(w(50)))
        let screen = try #require(
            TilingEngine.screen(for: id, in: core.state)
        )
        let chain = try #require(core.bspChain(of: space, on: screen))
        try #require(chain.zone.members.contains(w(50)))
        let response = core.resizeBspChain(
            w(50),
            axis: "y",
            delta: 400,
            space: space,
            toward: .both
        )
        #expect(
            response?.error
                == "a tiled sticky window can be resized only "
                + "in its home Space"
        )
        #expect(core.state.workspaces[id]?.runSizes.isEmpty == true)
    }

    @Test("BSP: a visitor in a chain that fits whole takes no weight")
    func visitorInAFittingChain() throws {
        let (core, id) = makeSpace(
            "bsp",
            windows: 4,
            focus: 2,
            height: 1500
        ) {
            $0.execute("bsp.set_strategy", args: [.string("alternating")])
        }
        core.state.workspaces.ensureSpace(SpaceID("2"))
        for id: UInt32 in 60...62 {
            core.state.windows.upsert(
                ManagedWindow(id: w(id), pid: 900_060, appName: "H")
            )
            core.state.workspaces.add(w(id), to: SpaceID("2"))
        }
        core.state.windows.upsert(
            ManagedWindow(
                id: w(50),
                pid: 900_050,
                appName: "Traveler",
                stickyScope: .global
            )
        )
        core.state.workspaces.add(w(50), to: SpaceID("2"))
        core.retile(animated: false)
        let space = try #require(core.state.workspaces[id])
        let screen = try #require(
            TilingEngine.screen(for: id, in: core.state)
        )
        let chain = try #require(core.bspChain(of: space, on: screen))
        try #require(chain.zone.members.contains(w(50)))
        try #require(chain.zone.run(in: chain.context) == nil)
        let response = core.resizeBspChain(
            w(50),
            axis: "y",
            delta: 10,
            space: space,
            toward: .both
        )
        #expect(
            response?.error
                == "a tiled sticky window can be resized only "
                + "in its home Space"
        )
        #expect(core.state.workspaces[id]?.stackWeights[w(50)] == nil)
    }
}
