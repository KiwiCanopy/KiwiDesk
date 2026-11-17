import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A screen's own pocket edge reaches what the pocket draws there
/// (#3376): the handle's band, its approach and the spec the panel
/// wears, on the host's real main screen, so the per-display
/// readers are exercised through `KiwiCore.shelf(on:)`.
@Suite(
    "Per-screen pocket edge wiring (#3376)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct PocketScreenEdgeWiringTests {
    private func core() throws -> (KiwiCore, DisplayID) {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-edge-\(UUID().uuidString)")
        )
        let screen = try #require(NSScreen.main)
        let id = try #require(screen.kiwiDisplayID)
        let space = try #require(core.state.workspaces.activeSpace)
        core.state.workspaces.upsertDisplay(
            Display(id: id, name: "Main", frame: screen.frame)
        )
        core.state.workspaces.assign(space, to: id)
        core.tiler.settings.spaceBarStyle.visibility = .hidden
        core.execute(
            "kiwishelf.set_pocket_visibility",
            args: [.string("auto")]
        )
        core.execute("kiwishelf.set_pocket_edge", args: [.string("bottom")])
        return (core, id)
    }

    /// Gives the main screen its own `edge`, the pocket's staying
    /// bottom.
    private func pin(_ core: KiwiCore, _ id: DisplayID, _ edge: AppBarEdge) {
        let fingerprint = core.screenFingerprint(of: id) ?? ""
        core.tiler.settings.kiwishelf.pocketEdgeOverride = [
            fingerprint: edge
        ]
    }

    @Test("the handle stands on the screen's own edge")
    func handleTakesTheScreensEdge() throws {
        let (core, id) = try core()
        let flat = try #require(core.pocketHandleFrame(on: id, risen: false))
        #expect(flat.width > flat.height)
        pin(core, id, .left)
        #expect(core.tiler.settings.kiwishelf.pocketEdge == .bottom)
        let side = try #require(core.pocketHandleFrame(on: id, risen: false))
        #expect(side.height > side.width)
    }

    @Test("the whole mark stands on the screen's own edge")
    func markTakesTheScreensEdge() throws {
        let (core, id) = try core()
        core.execute(
            "kiwishelf.set_pocket_visibility",
            args: [.string("always")]
        )
        pin(core, id, .left)
        let mark = try #require(core.pocketMarkFrame(on: id))
        let visible = GeometryUtils.axVisibleFrame(
            of: try #require(NSScreen.main)
        )
        // On the left edge, not centred along the bottom.
        #expect(mark.midX < visible.midX)
        #expect(mark.midY < visible.maxY && mark.midY > visible.minY)
    }

    @Test("the approach and the panel's spec take the screen's edge")
    func approachAndSpecFollow() throws {
        let (core, id) = try core()
        pin(core, id, .right)
        var hiding = KiwiCore.HidingShelves()
        core.filePocketApproaches(into: &hiding)
        let target = try #require(
            hiding.targets[core.pocketApproachKey(on: id)]
        )
        let tab = try #require(target.handle)
        #expect(tab.height > tab.width)
        core.updatePocketPlate(slots: [:])
        let spec = try #require(core.pocketPlate.specs[id])
        #expect(spec.handle == .right)
        #expect(spec.shelf.pocketEdge == .right)
    }
}
