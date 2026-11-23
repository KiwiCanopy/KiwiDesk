import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A reload of an `init.lua` that stops calling `set_display_areas`
/// makes the screen whole again, once, at the load's tail; a split
/// Lua did not make stays (#3573).
@Suite("Lua split reload", .serialized)
@MainActor
struct LuaAreaSplitReloadTests {
    private let wide = Display(
        id: DisplayID(900_573),
        name: "Wide",
        frame: CGRect(x: 0, y: 0, width: 3440, height: 1440)
    )
    private let split =
        #"KiwiDesk.set_display_areas(1, "side_by_side", 1720, 1720)"#

    private func core() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-area-lua-\(UUID().uuidString)")
        )
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try core.guiConfigStore.save(GuiConfig())
        core.state.workspaces.upsertDisplay(wide)
        return core
    }

    private func load(_ core: KiwiCore, _ lua: String) throws {
        try (lua + "\n").write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.loadConfig()
    }

    private func areas(_ core: KiwiCore) -> Int {
        core.state.workspaces.placements(of: wide.id).count
    }

    @Test func droppedSplitGoesWhole() throws {
        let core = try core()
        try load(core, split)
        try #require(areas(core) == 2)
        try load(core, "-- no areas")
        #expect(areas(core) == 1)
        #expect(
            core.tiler.settings.displayAreas[wide.fingerprint]?.isWhole
                != false
        )
    }

    @Test func declaredSplitStays() throws {
        let core = try core()
        try load(core, split)
        try load(core, split)
        #expect(areas(core) == 2)
        // Still Lua's, so the next load that drops it resets it.
        try load(core, "-- no areas")
        #expect(areas(core) == 1)
    }

    /// A split written outside a load is not Lua's to undo.
    @Test func splitMadeElsewhereStays() throws {
        let core = try core()
        try load(core, split)
        core.execute(
            "set_display_areas",
            args: [
                .string(wide.fingerprint), .string("side_by_side"),
                .number(1147), .number(1146), .number(1147),
            ]
        )
        try load(core, "-- no areas")
        #expect(areas(core) == 3)
    }

    /// A profile's split, as a Settings Save stores it, survives a
    /// reload of an `init.lua` that never mentions areas.
    @Test func profileSplitStays() throws {
        let core = try core()
        try load(core, "-- no areas")
        let halves = try #require(
            ScreenSplit.whole(width: 3440, height: 1440)
                .splitting(0, .sideBySide)
        )
        var profile = core.buildProfile(name: "desk", modes: nil)
        profile.settings.displayAreas[wide.fingerprint] = halves
        _ = try core.saveProfile(profile)
        core.apply(profile: profile, cause: .explicit)
        try #require(areas(core) == 2)
        try load(core, "-- no areas")
        #expect(areas(core) == 2)
    }

    /// The reset is a merge: a pin on the area that goes moves to
    /// the survivor (ruling 22).
    @Test func resetMovesThePin() throws {
        let core = try core()
        try load(core, split)
        let right = ScreenAreaKey(parsing: "\(wide.fingerprint)#1")
        core.spacePins["2"] = right.description
        try load(core, "-- no areas")
        let pin = ScreenAreaKey(parsing: core.spacePins["2"] ?? "")
        #expect(pin.fingerprint == wide.fingerprint)
        #expect(pin.areaID == 0)
    }
}
