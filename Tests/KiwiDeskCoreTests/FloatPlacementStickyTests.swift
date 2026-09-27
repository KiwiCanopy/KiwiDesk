import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// Sticky windows and the #1708 placement: a sticky keeps its
/// re-anchor, and the cascade counts every float a Space draws —
/// now, and once an unshown target activates.
@Suite("Float placement and sticky windows", .serialized)
@MainActor
struct FloatPlacementStickyTests {
    /// A scrolled-out column: partly past the screen's left edge.
    private let slot = CGRect(x: -300, y: 60, width: 600, height: 900)
    private let screen = CGRect(x: 0, y: 0, width: 1600, height: 1000)

    /// Space 1 in scrolling with w1 and w2 (w2 focused at `slot`),
    /// Space 2 floating and unshown. The animation engine is off so
    /// a relayout lands synchronously on the `apply` hook.
    private func setup(
        applied: @escaping @MainActor (WindowID, CGRect) -> Void = {
            _,
            _ in
        }
    ) -> KiwiCore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: dir)
        // Pin the display (#531): the region is read through it.
        let screen = self.screen
        core.tiler.visibleBounds = { _ in screen }
        core.execute(
            "set_mode",
            args: [.string("1"), .string("scrolling")]
        )
        core.state.workspaces.ensureSpace(SpaceID("2"))
        core.execute(
            "set_mode",
            args: [.string("2"), .string("floating")]
        )
        for index in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(index)),
                        pid: 1,
                        appName: "A"
                    )
                )
            )
        }
        core.state.apply(.windowResized(WindowID(1), slot))
        core.state.apply(.windowResized(WindowID(2), slot))
        core.state.apply(.windowFocused(WindowID(2)))
        core.tiler.animation.isEnabled = false
        core.tiler.animation.apply = { id, frame, _ in
            applied(id, frame)
        }
        return core
    }

    private func centred(_ core: KiwiCore) throws -> CGRect {
        let region = try #require(core.floatGrowBounds(on: SpaceID("2")))
        return FloatPlacement.centered(in: region)
    }

    /// A display sticky reaches the filing only crossing displays,
    /// which no fake screen can stage; the gate is asked directly.
    @Test("a sticky window keeps the re-anchor")
    func stickyStandsDown() {
        let core = setup()
        core.state.workspaces.add(WindowID(2), to: SpaceID("2"))
        #expect(core.placeEnteringFloat(WindowID(2), wasFloat: false))
        core.tiler.forgetStash(WindowID(2))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(3),
                    pid: 1,
                    appName: "Sticky",
                    frame: slot,
                    stickyScope: .display
                )
            )
        )
        core.state.workspaces.add(WindowID(3), to: SpaceID("2"))
        // Drawn on the floating Space, so only the sticky gate
        // stands between it and a seed.
        core.state.workspaces.activate(SpaceID("2"))
        #expect(core.isEffectiveFloatForPlacement(WindowID(3)))
        #expect(!core.placeEnteringFloat(WindowID(3), wasFloat: false))
        #expect(core.tiler.stashOriginal(WindowID(3)) == nil)
    }

    /// A ∞ float drawn on Space 1 but a member of Space 3 holds the
    /// centre: the cascade reads what the Space DRAWS.
    @Test("the cascade steps off a sticky traveler drawn there")
    func travelerIsAvoided() throws {
        var frames: [WindowID: CGRect] = [:]
        let core = setup { frames[$0] = $1 }
        core.execute("set_mode", args: [.string("1"), .string("bsp")])
        let region = try #require(core.floatGrowBounds(on: SpaceID("1")))
        let centre = FloatPlacement.centered(in: region)
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(4),
                    pid: 2,
                    appName: "Sticky",
                    frame: centre,
                    stickyScope: .global
                )
            )
        )
        core.state.setFloating(WindowID(4), true)
        core.state.workspaces.ensureSpace(SpaceID("3"))
        core.state.workspaces.add(WindowID(4), to: SpaceID("3"))
        core.state.apply(.windowFocused(WindowID(2)))
        #expect(core.state.workspaces.space(of: WindowID(4)) == SpaceID("3"))
        #expect(core.execute("toggle_floating").isSuccess)
        let step = FloatPlacement.cascadeStep
        #expect(frames[WindowID(2)] == centre.offsetBy(dx: step, dy: step))
    }

    /// Space 2 is unshown: the ∞ float is drawn on Space 1 now and
    /// on Space 2 once it activates, where the seed is delivered.
    @Test("an unshown target's cascade counts every ∞ float")
    func unshownTargetCountsGlobalStickies() throws {
        let core = setup()
        let centre = try centred(core)
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(4),
                    pid: 2,
                    appName: "Sticky",
                    frame: centre,
                    stickyScope: .global
                )
            )
        )
        core.state.setFloating(WindowID(4), true)
        core.state.apply(.windowFocused(WindowID(2)))
        #expect(
            core.execute("move_to_space", args: [.string("2")]).isSuccess
        )
        let step = FloatPlacement.cascadeStep
        #expect(
            core.tiler.stashOriginal(WindowID(2))
                == centre.offsetBy(dx: step, dy: step)
        )
    }

    /// A 📌 float filed in unshown Space 2 renders there once it
    /// activates, where the moved window's seed is delivered.
    @Test("an unshown target's cascade counts its own sticky floats")
    func unshownTargetCountsItsOwnStickies() throws {
        let core = setup()
        let centre = try centred(core)
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(4),
                    pid: 2,
                    appName: "Sticky",
                    frame: centre,
                    stickyScope: .display
                )
            )
        )
        core.state.setFloating(WindowID(4), true)
        core.state.workspaces.add(WindowID(4), to: SpaceID("2"))
        core.state.apply(.windowFocused(WindowID(2)))
        #expect(
            core.execute("move_to_space", args: [.string("2")]).isSuccess
        )
        let step = FloatPlacement.cascadeStep
        #expect(
            core.tiler.stashOriginal(WindowID(2))
                == centre.offsetBy(dx: step, dy: step)
        )
    }
}
