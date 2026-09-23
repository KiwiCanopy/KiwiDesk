import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The ladder a Desktop binding's scope adds to (#1609), through
/// the one gate every door takes: a binding scoped to the
/// connected screen setup, then one for all setups, then the
/// profile holding the setup. The owner's case is the fixture —
/// Desktop 1 bound to "Starter" for all setups while "Vision"
/// holds the connected screens.
///
/// `.serialized`: the topology overrides are process-global.
@MainActor
@Suite("Desktop binding scope: the gate (#1609)", .serialized)
struct DesktopBindingScopeGateTests {
    private let stamp = DesktopIdentity(raw: "STAMP-SCOPE")
    /// The connected screen's fingerprint.
    private let here = ["D1:100x100"]
    /// A one-screen setup that is not connected.
    private let elsewhere = ["V1:200x100"]

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-scope-\(UUID().uuidString)"
                )
        )
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "D1",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100)
            )
        )
        return core
    }

    private func profile(_ name: String, holds: [String]) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: holds)],
            spaceModes: ["1": .bsp],
            settings: TilingSettings()
        )
    }

    private func pinTopology() {
        NativeSpaces.spacesOverride = [
            NativeSpace(
                id: 11,
                displayUUID: "UUID-A",
                isCurrent: true,
                identity: stamp
            )
        ]
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        NativeSpaces.activeSpaceIDOverride = 11
    }

    private func reset() {
        NativeSpaces.spacesOverride = nil
        NativeSpaces.mainDisplayUUIDOverride = nil
        NativeSpaces.activeSpaceIDOverride = nil
    }

    /// "Starter" holds another setup, "Vision" the connected one.
    private func seeded() throws -> KiwiCore {
        let core = makeCore()
        try core.profiles.save(profile("Starter", holds: elsewhere))
        try core.profiles.save(profile("Vision", holds: here))
        return core
    }

    private func bind(
        _ core: KiwiCore,
        _ name: String,
        screens: [String] = []
    ) -> CommandResponse {
        core.execute(
            "bind_profile_to_desktop",
            args: [.number(1), .string(name)]
                + screens.map { .string($0) }
        )
    }

    private var snapshot: DesktopSnapshot {
        NativeSpaces.desktopSnapshot()
    }

    @Test("a binding for these screens outranks one for all")
    func specificOutranksAll() throws {
        defer { reset() }
        pinTopology()
        let core = try seeded()
        _ = bind(core, "Starter")
        #expect(core.profiles.currentName == "Starter")
        _ = bind(core, "Vision", screens: here)
        #expect(core.profiles.currentName == "Vision")
        let reading = try #require(
            core.mainDesktopBinding(in: snapshot)
                .flatMap(core.boundReading(of:))
        )
        #expect(
            reading == BoundReading(name: "Vision", setup: here, over: nil)
        )
    }

    /// The door's stand-down for the profile already live asks
    /// the gate's own rank: live and listed for all setups is not
    /// the pick where an entry is scoped to these screens.
    @Test("the door does not stand down for a live all-setups entry")
    func standDownAsksTheScope() throws {
        defer { reset() }
        pinTopology()
        let core = try seeded()
        _ = bind(core, "Starter")
        #expect(core.profiles.currentName == "Starter")
        let key = try #require(snapshot.mainCurrentKey)
        core.desktopBindings[key]?.bind("Vision", setup: here) { _ in 1 }
        core.applyDesktopBinding(in: snapshot)
        #expect(core.profiles.currentName == "Vision")
        // Live AND the pick: stands down with no file read.
        try FileManager.default.removeItem(
            at: core.profiles.directory
                .appendingPathComponent("Vision.json")
        )
        #expect(core.bindingPicksLiveProfile(core.desktopBindings[key]!))
    }

    @Test("an all-setups pick names the holder it loads over")
    func readingNamesTheHolder() throws {
        defer { reset() }
        pinTopology()
        let core = try seeded()
        _ = bind(core, "Starter")
        let binding = try #require(core.mainDesktopBinding(in: snapshot))
        #expect(
            core.boundReading(of: binding)
                == BoundReading(name: "Starter", setup: nil, over: "Vision")
        )
        #expect(
            core.profileVerdict(activeBinding: binding).verdict
                == .boundToDesktop(
                    name: "Starter",
                    desktop: 1,
                    over: "Vision"
                )
        )
    }

    /// Every entry scoped elsewhere: the binding stands aside and
    /// the holder loads — rung 3.
    @Test("a binding for other screens stands aside")
    func otherSetupsStandAside() throws {
        defer { reset() }
        pinTopology()
        let core = try seeded()
        _ = bind(core, "Starter", screens: elsewhere)
        let binding = try #require(core.mainDesktopBinding(in: snapshot))
        guard case .failure(.otherSetups) = core.boundProfile(of: binding)
        else {
            Issue.record("expected the binding to stand aside")
            return
        }
        #expect(core.boundReading(of: binding) == nil)
        #expect(
            core.profileVerdict(activeBinding: binding).verdict
                == .exactMonitors(name: "Vision")
        )
    }

    @Test("the verb files further arguments as the scope")
    func verbTakesScreens() throws {
        defer { reset() }
        pinTopology()
        let core = try seeded()
        #expect(bind(core, "Vision", screens: here) == .ok())
        #expect(
            core.desktopBindings[.identity(stamp)]?.entries
                == [.init(profile: "Vision", setup: here)]
        )
        let refused = core.execute(
            "bind_profile_to_desktop",
            args: [.number(1), .string("Vision"), .bool(true)]
        )
        #expect(refused != .ok())
    }
}
