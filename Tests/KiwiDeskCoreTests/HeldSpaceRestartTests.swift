import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Held Spaces survive a restart (#1646): every snapshot carries
/// them, and boot holds them again before the replay files their
/// windows. Process A is `HeldSpaceDesk`'s owner desk unplugged —
/// the DELL's 3 held as 5 (10, 11), its 4 as 6 (12). Process B
/// shares A's config directory, loads a profile for the screens
/// it boots on, scans the given windows into Space 1 and runs the
/// boot tail from A's snapshot.
@Suite("Held Spaces across a restart (#1646)", .serialized)
@MainActor
struct HeldSpaceRestartTests {
    let desk = HeldSpaceDesk()

    func unplugged() throws -> KiwiCore {
        let core = try desk.docked()
        core.handle(.displaysChanged([desk.builtIn]))
        #expect(core.state.heldSpaces.count == 2)
        return core
    }

    func crossed(_ snapshot: StateSnapshot) throws -> StateSnapshot {
        try JSONDecoder().decode(
            StateSnapshot.self,
            from: JSONEncoder().encode(snapshot)
        )
    }

    func heldCount(_ snapshot: StateSnapshot?) -> Int? {
        snapshot?.spaces.filter { $0.held != nil }.count
    }

    /// A census hosting `ids` on an unshown Desktop.
    func census(hosting ids: [Int]) -> DesktopCensus {
        var hosts: [WindowID: DesktopCensus.Host] = [:]
        for id in ids {
            hosts[WindowID(UInt32(id))] = .init(space: 4, pid: 1, isUp: true)
        }
        return DesktopCensus(hosts: hosts, shown: [])
    }

    /// Process B on `screens`, under `profile` when one is named.
    func boot(
        from a: KiwiCore,
        screens: [Display],
        profile: String?,
        windows: [Int] = [13, 10, 11, 12],
        session: StateSnapshot,
        directory: URL? = nil,
        prepare: (KiwiCore) -> Void = { _ in }
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory: directory ?? a.configDirectory
        )
        prepare(core)
        core.handle(.displaysChanged(screens))
        if let profile {
            core.execute("load_profile", args: [.string(profile)])
        }
        core.state.workspaces.ensureSpace(SpaceID(1))
        for id in windows {
            core.state.windows.upsert(desk.window(id))
            core.state.workspaces.add(WindowID(UInt32(id)), to: SpaceID(1))
        }
        core.arrangeBootDesk(session: session)
        return core
    }

    func expectHeldAsLeft(_ b: KiwiCore, _ a: KiwiCore) {
        #expect(b.state.heldSpaces == a.state.heldSpaces)
        #expect(desk.members(b, 5) == desk.ids([10, 11]))
        #expect(desk.members(b, 6) == desk.ids([12]))
        #expect(desk.members(b, 1) == desk.ids([13]))
    }

    @Test("a quit and relaunch keeps the held Spaces and their origin")
    func plainRestartKeepsHolds() throws {
        let a = try unplugged()
        let session = try crossed(a.sessionSnapshot())
        #expect(heldCount(session) == 2)
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
        #expect(heldCount(reader.takeBootSnapshot()) == 2)
        writer.shutdownCleanly()
        #expect(heldCount(reader.takeBootSnapshot()) == 2)
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
        try a.profiles.save(desk.fiveSpaces())
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

    @Test("a renumber skips every number the snapshot records")
    func renumberSkipsRecordedNumbers() throws {
        let a = try unplugged()
        a.state.workspaces.ensureSpace(SpaceID(7))
        a.state.windows.upsert(desk.window(14))
        a.state.workspaces.add(WindowID(14), to: SpaceID(7))
        try a.profiles.save(desk.fiveSpaces())
        let b = boot(
            from: a,
            screens: [desk.builtIn],
            profile: "five",
            windows: [13, 10, 11, 12, 14],
            session: try crossed(a.sessionSnapshot())
        )
        #expect(b.state.heldSpaces[SpaceID(8)]?.name == SpaceID(3))
        #expect(b.state.heldSpaces[SpaceID(9)]?.name == SpaceID(4))
        #expect(desk.members(b, 8) == desk.ids([10, 11]))
        #expect(b.state.workspaces.space(of: WindowID(14)) == SpaceID(1))
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
        let order = [1, 2, 4, 5].map { SpaceID($0) }
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
        // The profile's mode, not the held Space's record, and
        // the declared Spaces keep their place in the bar.
        #expect(b.state.workspaces[SpaceID(4)]?.mode == .stack)
        #expect(b.state.workspaces.allSpaces.map(\.id) == order)
    }

    @Test("a hidden app's window keeps its held Space across the restart")
    func hiddenMemberKeepsTheHold() throws {
        let a = try unplugged()
        a.handle(.windowHidden(WindowID(12)))
        #expect(a.state.heldSpaces[SpaceID(6)] != nil)
        let b = boot(
            from: a,
            screens: [desk.builtIn],
            profile: "solo",
            windows: [13, 10, 11],
            session: try crossed(a.sessionSnapshot())
        )
        b.desktopMemory.readCensus = { _ in self.census(hosting: [12]) }
        b.retireGoneHeldMembers()
        #expect(b.state.heldSpaces[SpaceID(6)]?.name == SpaceID(4))
        #expect(
            b.state.rememberedSpaces[WindowID(12)] == .restored(SpaceID(6))
        )
        b.handle(.windowCreated(desk.window(12)))
        #expect(b.state.workspaces.space(of: WindowID(12)) == SpaceID(6))
    }

    @Test("a window on another Desktop keeps its held Space too")
    func awayMemberKeepsTheHold() throws {
        let a = try unplugged()
        let away = WindowID(12)
        a.state.workspaces.remove(away)
        a.state.windows.remove(away)
        a.state.awayWindows[away] = AwayWindow(
            id: away,
            pid: 1,
            appName: "App12",
            appBundleID: nil,
            nativeSpace: 4
        )
        a.state.rememberedSpaces[away] = .departed(SpaceID(6))
        a.retile()
        #expect(a.state.heldSpaces[SpaceID(6)] != nil)
        let b = boot(
            from: a,
            screens: [desk.builtIn],
            profile: "solo",
            windows: [13, 10, 11],
            session: try crossed(a.sessionSnapshot())
        )
        b.desktopMemory.readCensus = { _ in self.census(hosting: [12]) }
        b.retireGoneHeldMembers()
        #expect(b.state.heldSpaces[SpaceID(6)] != nil)
        #expect(b.state.rememberedSpace(of: away) == SpaceID(6))
    }

    @Test("a window still launching at boot keeps its held Space")
    func lateMemberKeepsTheHold() throws {
        let a = try unplugged()
        let b = boot(
            from: a,
            screens: [desk.builtIn],
            profile: "solo",
            windows: [13, 12],
            session: try crossed(a.sessionSnapshot())
        )
        b.desktopMemory.readCensus = { _ in
            self.census(hosting: [13, 10, 11, 12])
        }
        b.retireGoneHeldMembers()
        #expect(b.state.heldSpaces[SpaceID(5)]?.name == SpaceID(3))
        b.handle(.windowCreated(desk.window(10)))
        #expect(b.state.workspaces.space(of: WindowID(10)) == SpaceID(5))
    }

    @Test("a hold whose windows are gone ends once the census says so")
    func goneWindowsRetireAfterBoot() throws {
        let a = try unplugged()
        let b = boot(
            from: a,
            screens: [desk.builtIn],
            profile: "solo",
            windows: [13, 12],
            session: try crossed(a.sessionSnapshot())
        )
        // Kept through the replay: nothing has judged 10 and 11.
        #expect(b.state.heldSpaces[SpaceID(5)] != nil)
        b.desktopMemory.readCensus = { _ in nil }
        b.retireGoneHeldMembers()
        #expect(b.state.heldSpaces[SpaceID(5)] != nil)
        b.desktopMemory.readCensus = { _ in self.census(hosting: [13, 12]) }
        b.retireGoneHeldMembers()
        #expect(b.state.heldSpaces[SpaceID(5)] == nil)
        #expect(b.state.workspaces[SpaceID(5)] == nil)
        #expect(b.state.heldSpaces[SpaceID(6)]?.name == SpaceID(4))
    }
}
