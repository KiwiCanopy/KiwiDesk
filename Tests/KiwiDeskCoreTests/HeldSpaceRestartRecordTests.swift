import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The held record's stored shape and its enders (#1646), and a
/// boot under no profile: `HeldSpaceRestartTests`' desk and boot.
@Suite("Held Space restart record (#1646)", .serialized)
@MainActor
struct HeldSpaceRestartRecordTests {
    private let t = HeldSpaceRestartTests()
    private var desk: HeldSpaceDesk { t.desk }

    private func freshDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwi-1646-\(UUID().uuidString)")
    }

    @Test("an unreadable hold costs only itself")
    func unreadableRecordCostsOnlyItself() throws {
        let a = try t.unplugged()
        let snapshot = a.sessionSnapshot()
        let data = try JSONEncoder().encode(snapshot)
        var json = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var spaces = try #require(json["spaces"] as? [[String: Any]])
        let index = try #require(
            spaces.firstIndex { $0["id"] as? String == "5" }
        )
        var held = try #require(spaces[index]["held"] as? [String: Any])
        var origin = try #require(held["origin"] as? [String: Any])
        origin["arrangement"] = ["kind": "galaxy", "name": "desk"]
        held["origin"] = origin
        spaces[index]["held"] = held
        json["spaces"] = spaces
        let decoded = try JSONDecoder().decode(
            StateSnapshot.self,
            from: JSONSerialization.data(withJSONObject: json)
        )
        #expect(decoded.spaces.map(\.id) == snapshot.spaces.map(\.id))
        #expect(decoded.spaces[index].held == nil)
        #expect(
            decoded.spaces[index].windows == snapshot.spaces[index].windows
        )
        #expect(
            decoded.spaces.filter { $0.held != nil }.map(\.id) == ["6"]
        )
        #expect(decoded.windows == snapshot.windows)
        // An older build's record has no hold at all.
        for i in spaces.indices { spaces[i]["held"] = nil }
        json["spaces"] = spaces
        let older = try JSONDecoder().decode(
            StateSnapshot.self,
            from: JSONSerialization.data(withJSONObject: json)
        )
        #expect(older.spaces.allSatisfy { $0.held == nil })
    }

    /// The stored spelling, which a property rename would change
    /// through the synthesized keys.
    @Test("the hold's stored keys are pinned")
    func storedKeysArePinned() throws {
        var space = Space(id: SpaceID(6))
        space.windows = [WindowID(12)]
        let record = StateSnapshot.SpaceRecord(
            space: space,
            held: .init(
                origin: HeldOrigin(
                    name: SpaceID(4),
                    screen: "DELL:2560x1440",
                    icon: "book",
                    arrangement: .standard("Dual")
                ),
                remembered: [WindowID(20)]
            )
        )
        let json = try #require(
            try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(record)
            ) as? [String: Any]
        )
        let held = try #require(json["held"] as? [String: Any])
        #expect(Set(held.keys) == ["origin", "remembered"])
        #expect(held["remembered"] as? [Int] == [20])
        let origin = try #require(held["origin"] as? [String: Any])
        #expect(Set(origin.keys) == ["name", "screen", "icon", "arrangement"])
        #expect(origin["name"] as? String == "4")
        let arrangement = try #require(
            origin["arrangement"] as? [String: String]
        )
        #expect(arrangement == ["kind": "standard", "name": "Dual"])
        let profile = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(HeldOrigin.Arrangement.profile("desk"))
        )
        #expect(
            profile as? [String: String] == [
                "kind": "profile", "name": "desk",
            ]
        )
    }

    @Test("discarding the saved arrangement deletes the record, not the hold")
    func tierOneKeepsLiveHolds() throws {
        let a = try t.unplugged()
        a.onLog = { _ in }
        a.crash.captureState = { [weak a] in a?.sessionSnapshot() }
        a.crash.bootTime = { .distantPast }
        a.crash.autosave()
        #expect(t.heldCount(a.crash.takeBootSnapshot()) == 2)
        a.crash.autosave()
        a.crash.shutdownCleanly()
        a.discardSavedArrangement()
        #expect(a.crash.takeBootSnapshot() == nil)
        #expect(a.state.heldSpaces.count == 2)
    }

    /// The outcome only: the reset's prune empties every held
    /// Space, which the retire ends on its own, so this does not
    /// pin the reset's own `forgetHeldSpaces`.
    @Test("Reset All Settings ends every hold, so no snapshot carries one")
    func tierTwoForgetsHolds() throws {
        let a = try t.unplugged()
        a.onLog = { _ in }
        a.resetAllSettings(trash: { _ in })
        #expect(a.state.heldSpaces.isEmpty)
        #expect(t.heldCount(a.sessionSnapshot()) == 0)
    }

    @Test("with no arrangement live, a hold stays held and unpinned")
    func noArrangementKeepsTheHold() throws {
        let a = try t.unplugged()
        let b = t.boot(
            from: a,
            screens: [desk.builtIn, desk.dell],
            profile: nil,
            session: try t.crossed(a.sessionSnapshot()),
            directory: freshDirectory()
        )
        try #require(b.liveHome == nil)
        #expect(b.state.heldSpaces == a.state.heldSpaces)
        #expect(b.spacePins[SpaceID(5)] == nil)
        #expect(desk.members(b, 5) == desk.ids([10, 11]))
    }

    /// A Standard is not the profile the holds left, so nothing
    /// goes home: each stays held, pinned back to its screen, and
    /// off every number the Standard composes.
    @Test("under a composed Standard a hold stays held, pinned home")
    func standardBootPinsTheHold() throws {
        let a = try t.unplugged()
        let b = t.boot(
            from: a,
            screens: [desk.builtIn, desk.dell],
            profile: nil,
            session: try t.crossed(a.sessionSnapshot()),
            directory: freshDirectory(),
            prepare: { try? $0.guiConfigStore.save(GuiConfig()) }
        )
        let home = try #require(b.liveHome)
        guard case .standard = home.arrangement else {
            Issue.record("expected a Standard, got \(home.arrangement)")
            return
        }
        let held = try #require(
            b.state.heldSpaces.first { $0.value.name == SpaceID(3) }
        )
        #expect(!home.declared.contains(held.key))
        #expect(b.spacePins[held.key] == desk.dell.fingerprint)
        #expect(desk.members(b, Int(held.key.raw) ?? 0) == desk.ids([10, 11]))
        #expect(b.state.heldSpaces.count == 2)
    }

    /// The snapshot's own arrangement stamp decodes on its own: an
    /// unreadable one costs only itself, and the replay treats the
    /// snapshot as unstamped, replaying every mode.
    @Test("an unreadable arrangement stamp costs only itself")
    func unreadableArrangementCostsOnlyItself() throws {
        let a = try t.unplugged()
        a.setSpaceMode(SpaceID(1), .monocle)
        let snapshot = a.sessionSnapshot()
        var json = try #require(
            try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(snapshot)
            ) as? [String: Any]
        )
        json["arrangement"] = ["kind": "galaxy", "name": "x"]
        let decoded = try JSONDecoder().decode(
            StateSnapshot.self,
            from: JSONSerialization.data(withJSONObject: json)
        )
        #expect(decoded.arrangement == nil)
        #expect(decoded.spaces.map(\.id) == snapshot.spaces.map(\.id))
        let b = t.boot(
            from: a,
            screens: [desk.builtIn],
            profile: "solo",
            session: decoded
        )
        #expect(b.state.workspaces[SpaceID(1)]?.mode == .monocle)
    }

    /// A snapshot an older build wrote carries no stamp, so its
    /// modes replay even under another arrangement — the one boot
    /// after the upgrade keeps the pre-stamp behaviour.
    @Test("an unstamped snapshot replays its modes")
    func unstampedSnapshotReplaysModes() throws {
        let core = try desk.docked()
        var solo = try core.profiles.read(name: "solo")
        solo.spaceModes[SpaceID(3)] = .floating
        try core.profiles.save(solo)
        var deskProfile = try core.profiles.read(name: "desk")
        deskProfile.spaceModes[SpaceID(3)] = .scrolling
        try core.profiles.save(deskProfile)
        core.handle(.displaysChanged([desk.builtIn]))
        var json = try #require(
            try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(core.sessionSnapshot())
            ) as? [String: Any]
        )
        json["arrangement"] = nil
        let older = try JSONDecoder().decode(
            StateSnapshot.self,
            from: JSONSerialization.data(withJSONObject: json)
        )
        #expect(older.arrangement == nil)
        let b = t.boot(
            from: core,
            screens: [desk.builtIn, desk.dell],
            profile: "desk",
            session: older
        )
        #expect(b.state.workspaces[SpaceID(3)]?.mode == .floating)
    }

    /// The unjudged mark ends with the filing it qualifies: at the
    /// window's arrival and at its close while away.
    @Test("the unjudged mark ends with its filing")
    func unjudgedMarkEndsWithItsFiling() {
        var state = StateCoordinator()
        let id = WindowID(77)
        state.unjudgedFilings.insert(id)
        state.forgetAway(id)
        #expect(!state.unjudgedFilings.contains(id))
        state.unjudgedFilings.insert(id)
        state.apply(
            .windowCreated(ManagedWindow(id: id, pid: 1, appName: "A"))
        )
        #expect(!state.unjudgedFilings.contains(id))
    }
}
