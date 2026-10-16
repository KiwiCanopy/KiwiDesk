import Foundation
import Testing

@testable import KiwiDeskCore

/// Which profiles a KiwiVision lens reaches (#2103 rulings 15, 16,
/// 38, 40): a profile's `lens_reach` leaves a lens out, a switch
/// into such a profile turns the lens off with its cause, a switch
/// back turns nothing on, and plain KiwiVision, a Lua-owned setup
/// and no live profile reach every lens.
@Suite("KiwiVision lens reach", .serialized)
@MainActor
struct KiwiVisionLensReachTests {
    private func makeCore(guiManaged: Bool = true) throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-lens-reach-\(UUID().uuidString)"
                )
        )
        core.eventLoop.ownKeyWindow = { nil }
        if guiManaged { try core.guiConfigStore.save(GuiConfig()) }
        let lens: [String: JSONValue] = [
            "name": .string("Writing"),
            "apps": .array([.string("test.kiwi.notes")]),
        ]
        #expect(
            core.execute("kiwivision.define_lens", args: [.object(lens)])
                .isSuccess
        )
        try core.profiles.write(profile("Laptop"))
        try core.profiles.write(profile("Studio", leavesOut: "WRITING"))
        try core.profiles.write(profile("Desk"))
        return core
    }

    private func profile(
        _ name: String,
        leavesOut lens: String? = nil
    ) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaceModes: [:],
            settings: TilingSettings(),
            lensReach: lens.map { [$0: false] }
        )
    }

    private func load(_ core: KiwiCore, _ name: String) {
        #expect(
            core.execute("load_profile", args: [.string(name)]).isSuccess
        )
    }

    @Test("a switch out of reach turns the lens off, with its cause")
    func switchOutOfReach() throws {
        let core = try makeCore()
        load(core, "Laptop")
        core.setKiwiVision(.lens("Writing"))
        var heard: [VisionChangeCause?] = []
        core.vision.onChange = { _, cause in heard.append(cause) }
        load(core, "Studio")
        #expect(core.kiwiVisionActive == .off)
        #expect(heard == [.outOfReach(lens: "Writing", profile: "Studio")])
        // A switch back is no press (ruling 16).
        load(core, "Laptop")
        #expect(core.kiwiVisionActive == .off)
    }

    @Test("a switch the lens reaches keeps it on, silently")
    func reachingSwitchKeepsIt() throws {
        let core = try makeCore()
        load(core, "Laptop")
        core.setKiwiVision(.lens("Writing"))
        var heard = 0
        core.vision.onChange = { _, _ in heard += 1 }
        load(core, "Desk")
        #expect(core.kiwiVisionActive == .lens("Writing"))
        #expect(heard == 0)
    }

    @Test("plain KiwiVision stays on across every switch")
    func plainStaysOn() throws {
        let core = try makeCore()
        load(core, "Laptop")
        core.setKiwiVision(.plain)
        load(core, "Studio")
        #expect(core.kiwiVisionActive == .plain)
    }

    /// Ruling 38: an "Applies to" edit writes the live file, and the
    /// marks follow the write rather than the next apply.
    @Test("a write of the live profile's file re-judges the lens on")
    func liveWriteFollows() throws {
        let core = try makeCore()
        load(core, "Laptop")
        core.setKiwiVision(.lens("Writing"))
        try core.profiles.write(profile("Laptop", leavesOut: "Writing"))
        #expect(core.kiwiVisionActive == .off)
    }

    @Test("the pick, the toggle and the chips refuse out of reach")
    func refusals() throws {
        let core = try makeCore()
        load(core, "Studio")
        core.setKiwiVision(.lens("Writing"))
        #expect(core.kiwiVisionActive == .off)
        let toggle = core.execute(
            "kiwivision.toggle",
            args: [.string("Writing")]
        )
        #expect(!toggle.isSuccess)
        #expect(toggle.error == "Writing does not reach Studio")
        #expect(
            core.kiwiVisionLensChoices == [
                VisionLensChoice(
                    name: "Writing",
                    refusal: .outOfReach(profile: "Studio")
                )
            ]
        )
    }

    /// The hook moves only with what it reports: a write of another
    /// profile refiles the live one unchanged.
    @Test("a write that moves no mark tells nobody")
    func quietWrite() throws {
        let core = try makeCore()
        load(core, "Laptop")
        var heard = 0
        core.vision.onReachChange = { heard += 1 }
        try core.profiles.write(profile("Desk", leavesOut: "Writing"))
        #expect(heard == 0)
        try core.profiles.write(profile("Laptop", leavesOut: "Writing"))
        #expect(heard == 1)
    }

    /// Ruling 40: a load that hands a Lua-owned setup to the GUI
    /// makes the profile's marks count, with no profile change.
    @Test("a load that changes the owner re-judges the lens on")
    func ownerFlip() throws {
        let core = try makeCore(guiManaged: false)
        load(core, "Studio")
        core.setKiwiVision(.lens("Writing"))
        #expect(core.kiwiVisionActive == .lens("Writing"))
        try core.guiConfigStore.save(GuiConfig())
        core.loadConfig()
        #expect(core.kiwiVisionActive == .off)
    }

    /// Rulings 38 and 40: nothing is stored for a built-in, and a
    /// Lua-owned setup's lenses reach every profile.
    @Test("no live profile and a Lua-owned setup reach every lens")
    func reachEverything() throws {
        let fresh = try makeCore()
        fresh.setKiwiVision(.lens("Writing"))
        #expect(fresh.kiwiVisionActive == .lens("Writing"))
        let lua = try makeCore(guiManaged: false)
        load(lua, "Studio")
        lua.setKiwiVision(.lens("Writing"))
        #expect(lua.kiwiVisionActive == .lens("Writing"))
    }
}
