import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Held Spaces survive a restart (#1646): every snapshot carries
/// them, and boot re-creates them before the replay files their
/// windows. Process A is `HeldSpaceDesk`'s owner desk unplugged —
/// the DELL's 3 held as 5 (10, 11), its 4 as 6 (12). Process B
/// shares A's config directory, loads a profile for the screens
/// it boots on, scans every window into Space 1 and runs the boot
/// tail from A's snapshot.
@Suite("Held Spaces across a restart (#1646)", .serialized)
@MainActor
struct HeldSpaceRestartTests {
    private let desk = HeldSpaceDesk()

    private func unplugged() throws -> KiwiCore {
        let core = try desk.docked()
        core.handle(.displaysChanged([desk.builtIn]))
        #expect(core.state.heldSpaces.count == 2)
        return core
    }

    private func crossed(_ snapshot: StateSnapshot) throws -> StateSnapshot {
        try JSONDecoder().decode(
            StateSnapshot.self,
            from: JSONEncoder().encode(snapshot)
        )
    }

    /// Process B on `screens` under `profile`, scanning `windows`.
    private func boot(
        from a: KiwiCore,
        screens: [Display],
        profile: String,
        windows: [Int] = [13, 10, 11, 12],
        session: StateSnapshot
    ) -> KiwiCore {
        let core = makeTestCore(configDirectory: a.configDirectory)
        core.handle(.displaysChanged(screens))
        core.execute("load_profile", args: [.string(profile)])
        for id in windows {
            let window = WindowID(UInt32(id))
            core.state.windows.upsert(
                ManagedWindow(id: window, pid: 1, appName: "App\(id)")
            )
            core.state.workspaces.add(window, to: SpaceID(1))
        }
        core.arrangeBootDesk(session: session)
        return core
    }

    private func expectHeldAsLeft(_ b: KiwiCore, _ a: KiwiCore) {
        #expect(b.state.heldSpaces == a.state.heldSpaces)
        #expect(desk.members(b, 5) == desk.ids([10, 11]))
        #expect(desk.members(b, 6) == desk.ids([12]))
        #expect(desk.members(b, 1) == desk.ids([13]))
    }

    @Test("a quit and relaunch keeps the held Spaces and their origin")
    func plainRestartKeepsHolds() throws {
        let a = try unplugged()
        let session = try crossed(a.sessionSnapshot())
        #expect(session.held.count == 2)
        let b = boot(
            from: a,
            screens: [desk.builtIn],
            profile: "solo",
            session: session
        )
        expectHeldAsLeft(b, a)
    }

    @Test("an in-place restart keeps them too")
    func inPlaceRestartKeepsHolds() throws {
        let a = try unplugged()
        let session = try crossed(a.sessionSnapshot(inPlace: true))
        let b = boot(
            from: a,
            screens: [desk.builtIn],
            profile: "solo",
            session: session
        )
        expectHeldAsLeft(b, a)
    }

    @Test("a quit's session file and a crash's autosave both carry them")
    func everyCaptureCarriesHolds() throws {
        let a = try unplugged()
        let dir = a.configDirectory.appendingPathComponent("snap")
        let writer = CrashRecovery(directory: dir)
        writer.captureState = { [weak a] in a?.sessionSnapshot() }
        let reader = CrashRecovery(directory: dir)
        reader.bootTime = { .distantPast }
        reader.onLog = { _ in }
        writer.autosave()
        #expect(reader.takeBootSnapshot()?.held.count == 2)
        writer.shutdownCleanly()
        #expect(reader.takeBootSnapshot()?.held.count == 2)
    }

    @Test("booting with the origin screen connected sends them home")
    func bootDockedRefiles() throws {
        let a = try unplugged()
        let b = boot(
            from: a,
            screens: [desk.builtIn, desk.dell],
            profile: "desk",
            session: try crossed(a.sessionSnapshot())
        )
        #expect(b.state.heldSpaces.isEmpty)
        #expect(b.state.workspaces[SpaceID(5)] == nil)
        #expect(b.state.workspaces[SpaceID(6)] == nil)
        #expect(desk.members(b, 3) == desk.ids([10, 11]))
        #expect(desk.members(b, 4) == desk.ids([12]))
    }

    @Test("a held id the booting arrangement declares is renumbered")
    func declaredHeldIDIsRenumbered() throws {
        let a = try unplugged()
        try a.profiles.save(
            desk.profile(
                "five",
                screens: [desk.builtIn.fingerprint],
                spaces: (1...5).map { SpaceID($0) }
            )
        )
        let b = boot(
            from: a,
            screens: [desk.builtIn],
            profile: "five",
            session: try crossed(a.sessionSnapshot())
        )
        // Past every live number (5) and every held one (6), in
        // the batch's order (#1664).
        #expect(b.state.heldSpaces[SpaceID(7)]?.name == SpaceID(3))
        #expect(b.state.heldSpaces[SpaceID(8)]?.name == SpaceID(4))
        #expect(b.state.heldSpaces[SpaceID(5)] == nil)
        #expect(desk.members(b, 7) == desk.ids([10, 11]))
        #expect(desk.members(b, 8) == desk.ids([12]))
        #expect(desk.members(b, 5).isEmpty)
    }

    @Test("a record going home under its own name files into its Space")
    func ownNameGoesHome() throws {
        let a = try desk.docked(dellSpaces: [SpaceID(4), SpaceID(5)])
        a.handle(.displaysChanged([desk.builtIn]))
        #expect(a.state.heldSpaces[SpaceID(4)]?.name == SpaceID(4))
        #expect(a.state.heldSpaces[SpaceID(5)]?.name == SpaceID(5))
        var wide = try a.profiles.read(name: "wide")
        wide.spaceModes[SpaceID(4)] = .stack
        try a.profiles.save(wide)
        let b = boot(
            from: a,
            screens: [desk.builtIn, desk.dell],
            profile: "wide",
            windows: [13, 100, 101],
            session: try crossed(a.sessionSnapshot())
        )
        #expect(b.state.heldSpaces.isEmpty)
        #expect(desk.members(b, 4) == desk.ids([100]))
        #expect(desk.members(b, 5) == desk.ids([101]))
        // The profile's mode, not the held Space's record.
        #expect(b.state.workspaces[SpaceID(4)]?.mode == .stack)
    }

    @Test("a held Space none of whose windows came back is not restored")
    func goneWindowsDropTheHold() throws {
        let a = try unplugged()
        let b = boot(
            from: a,
            screens: [desk.builtIn],
            profile: "solo",
            windows: [13, 12],
            session: try crossed(a.sessionSnapshot())
        )
        #expect(b.state.heldSpaces[SpaceID(5)] == nil)
        #expect(b.state.workspaces[SpaceID(5)] == nil)
        #expect(b.state.heldSpaces[SpaceID(6)]?.name == SpaceID(4))
        #expect(desk.members(b, 6) == desk.ids([12]))
    }

    @Test("an unreadable held record costs only itself")
    func unreadableRecordCostsOnlyItself() throws {
        let a = try unplugged()
        let snapshot = a.sessionSnapshot()
        let data = try JSONEncoder().encode(snapshot)
        var json = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var held = try #require(json["held"] as? [[String: Any]])
        var origin = try #require(held[0]["origin"] as? [String: Any])
        origin["arrangement"] = ["kind": "galaxy", "name": "desk"]
        held[0]["origin"] = origin
        json["held"] = held
        let decoded = try JSONDecoder().decode(
            StateSnapshot.self,
            from: JSONSerialization.data(withJSONObject: json)
        )
        #expect(decoded.held.map(\.spaceID) == [SpaceID(6)])
        #expect(decoded.spaces == snapshot.spaces)
        #expect(decoded.windows == snapshot.windows)
        // An older build's file has no list at all.
        json["held"] = nil
        let older = try JSONDecoder().decode(
            StateSnapshot.self,
            from: JSONSerialization.data(withJSONObject: json)
        )
        #expect(older.held.isEmpty)
        #expect(older.spaces == snapshot.spaces)
    }

    @Test("discarding the saved arrangement deletes the record, not the hold")
    func tierOneKeepsLiveHolds() throws {
        let a = try unplugged()
        a.onLog = { _ in }
        a.crash.captureState = { [weak a] in a?.sessionSnapshot() }
        a.crash.bootTime = { .distantPast }
        a.crash.autosave()
        #expect(a.crash.takeBootSnapshot()?.held.count == 2)
        a.crash.autosave()
        a.crash.shutdownCleanly()
        a.discardSavedArrangement()
        #expect(a.crash.takeBootSnapshot() == nil)
        #expect(a.state.heldSpaces.count == 2)
    }

    @Test("Reset All Settings ends every hold, so no snapshot carries one")
    func tierTwoForgetsHolds() throws {
        let a = try unplugged()
        a.onLog = { _ in }
        a.resetAllSettings(trash: { _ in })
        #expect(a.state.heldSpaces.isEmpty)
        #expect(a.sessionSnapshot().held.isEmpty)
    }
}
