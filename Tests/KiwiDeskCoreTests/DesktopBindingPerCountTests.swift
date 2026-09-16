import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// One Desktop, one profile per screen count (#1436): the record
/// lists them, the gate picks the one saved for the connected
/// screens, the verb replaces a same-count entry and adds
/// another, and every reader follows the list.
///
/// `.serialized`: the topology overrides are process-global.
@MainActor
@Suite("Desktop binding per screen count (#1436)", .serialized)
struct DesktopBindingPerCountTests {
    private let stamp = DesktopIdentity(raw: "STAMP-1")

    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-count-\(UUID().uuidString)"
                )
        )
    }

    /// Pinned 100x100 displays (#531), `"D<n>:100x100"`.
    private func connect(_ core: KiwiCore, _ count: Int) {
        for id in 1...3 {
            core.state.workspaces.removeDisplay(DisplayID(UInt32(id)))
        }
        for id in 0..<count {
            core.state.workspaces.upsertDisplay(
                Display(
                    id: DisplayID(UInt32(id + 1)),
                    name: "D\(id + 1)",
                    frame: CGRect(
                        x: CGFloat(id) * 100,
                        y: 0,
                        width: 100,
                        height: 100
                    )
                )
            )
        }
    }

    private func profile(_ name: String, screens: Int) -> Profile {
        Profile(
            name: name,
            monitorSets: [
                MonitorSet(
                    monitors: (1...screens).map { "D\($0):100x100" }
                )
            ],
            isDefault: false,
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

    private func bind(_ core: KiwiCore, _ name: String) {
        core.execute(
            "bind_profile_to_desktop",
            args: [.number(1), .string(name)]
        )
    }

    /// "Laptop" (1 screen), "Dual" (2 screens), "Solo" (1 screen)
    /// saved, and "Other" loaded clean so a binding's apply is
    /// visible.
    private func seeded(screens: Int) throws -> KiwiCore {
        let core = makeCore()
        connect(core, screens)
        for profile in [
            profile("Laptop", screens: 1),
            profile("Dual", screens: 2),
            profile("Solo", screens: 1),
            profile("Other", screens: screens),
        ] {
            try core.profiles.save(profile)
        }
        core.execute("load_profile", args: [.string("Other")])
        return core
    }

    @Test("another count adds beside; the same count replaces")
    func verbAddsAndReplaces() throws {
        defer { reset() }
        pinTopology()
        let core = try seeded(screens: 1)
        bind(core, "Laptop")
        bind(core, "Dual")
        #expect(
            core.desktopBindings[.identity(stamp)]?.profiles
                == ["Laptop", "Dual"]
        )
        bind(core, "Solo")
        #expect(
            core.desktopBindings[.identity(stamp)]?.profiles
                == ["Dual", "Solo"]
        )
        // Re-binding a listed name moves nothing.
        bind(core, "Dual")
        #expect(
            core.desktopBindings[.identity(stamp)]?.profiles
                == ["Dual", "Solo"]
        )
    }

    /// The gate picks the entry saved for the connected screens
    /// — the first in binding order that fits — and the doors
    /// load it.
    @Test("the gate picks the profile saved for the connected count")
    func gatePicksTheFit() throws {
        defer { reset() }
        pinTopology()
        let core = try seeded(screens: 1)
        bind(core, "Dual")
        bind(core, "Laptop")
        #expect(core.profiles.currentName == "Laptop")
        let binding = try #require(
            core.desktopBindings[.identity(stamp)]
        )
        #expect(
            try core.boundProfile(of: binding).get().name == "Laptop"
        )
        connect(core, 2)
        #expect(
            try core.boundProfile(of: binding).get().name == "Dual"
        )
        core.handleMonitorChange()
        #expect(core.profiles.currentName == "Dual")
    }

    /// No entry fits: the refusal carries every readable count,
    /// and the narrative lists the names.
    @Test("a list with no fit stands aside naming every entry")
    func noFitStandsAside() throws {
        defer { reset() }
        pinTopology()
        let core = try seeded(screens: 3)
        bind(core, "Laptop")
        bind(core, "Dual")
        let binding = try #require(
            core.desktopBindings[.identity(stamp)]
        )
        guard case .failure(let refusal) = core.boundProfile(of: binding)
        else {
            Issue.record("a three-screen host loaded a 1- or 2-screen profile")
            return
        }
        guard case .screenCount(let saved, let connected) = refusal
        else {
            Issue.record("expected .screenCount, got \(refusal)")
            return
        }
        #expect(saved.map(\.name) == ["Laptop", "Dual"])
        #expect(saved.map(\.count) == [1, 2])
        #expect(connected == 3)
        let line = refusal.narrative(binding: binding)
        #expect(line.contains("'Laptop' for 1, 'Dual' for 2 screen(s)"))
        #expect(line.contains("3 connected"))
        #expect(core.profiles.currentName == "Other")
    }

    /// A list whose files are all gone is unreadable; one whose
    /// screens are unknown waits.
    @Test("an unreadable list and an unknown display reading")
    func unreadableAndWaiting() throws {
        defer { reset() }
        pinTopology()
        let core = try seeded(screens: 1)
        let ghosts = DesktopBinding(
            profiles: ["Gone", "Also gone"],
            desktop: 1
        )
        guard case .failure(.unreadable) = core.boundProfile(of: ghosts)
        else {
            Issue.record("two missing files did not refuse as unreadable")
            return
        }
        connect(core, 0)
        let real = DesktopBinding(
            profiles: ["Laptop", "Dual"],
            desktop: 1
        )
        guard case .failure(.displaysUnknown) = core.boundProfile(of: real)
        else {
            Issue.record("no display reading did not make the binding wait")
            return
        }
    }

    /// `isProfileInEffect` and the verdict name the PICKED entry,
    /// never a listed one that stands aside.
    @Test("in-effect and the verdict name the picked entry")
    func readersFollowThePick() throws {
        defer { reset() }
        pinTopology()
        let core = try seeded(screens: 1)
        bind(core, "Dual")
        bind(core, "Laptop")
        #expect(core.isProfileInEffect("Laptop"))
        #expect(!core.isProfileInEffect("Dual"))
        let verdict = core.profileVerdict(
            activeBinding: core.mainDesktopBinding(
                in: NativeSpaces.desktopSnapshot()
            )
        )
        #expect(
            verdict.verdict == .boundToDesktop(name: "Laptop", desktop: 1)
        )
    }

    /// A rename follows into the list, in memory and in the
    /// sidecar, leaving the other entries as they are.
    @Test("a rename follows into the list")
    func renameFollowsTheList() throws {
        defer { reset() }
        pinTopology()
        let core = try seeded(screens: 1)
        bind(core, "Laptop")
        bind(core, "Dual")
        var stored = GuiConfig()
        stored.profileBindings = core.desktopBindings
        try core.guiConfigStore.save(stored)
        try core.renameProfile(from: "Dual", to: "Docked")
        #expect(
            core.desktopBindings[.identity(stamp)]?.profiles
                == ["Laptop", "Docked"]
        )
        let sidecar = try #require(core.guiConfigStore.load())
        #expect(
            sidecar.profileBindings[.identity(stamp)]?.profiles
                == ["Laptop", "Docked"]
        )
    }

    /// The record's own algebra, pure: an unsaved name is a
    /// class of its own, a listed name keeps its place and still
    /// evicts a same-count sibling, a count clears as one, a
    /// rename lands in place, and unbinding the last entry
    /// empties it.
    @Test("bind, unbind and rename on the record")
    func recordAlgebra() {
        var counts = ["A1": 1, "B1": 1, "C2": 2]
        var record = DesktopBinding(profiles: [], desktop: 1)
        record.bind("A1") { counts[$0] }
        record.bind("C2") { counts[$0] }
        record.bind("B1") { counts[$0] }
        #expect(record.profiles == ["C2", "B1"])
        record.bind("Unsaved") { counts[$0] }
        record.bind("Unsaved too") { counts[$0] }
        #expect(record.profiles == ["C2", "B1", "Unsaved too"])
        // "Unsaved too" is saved at 1 screen: two on one count
        // until the next bind of either evicts the other.
        counts["Unsaved too"] = 1
        record.bind("B1") { counts[$0] }
        #expect(record.profiles == ["C2", "B1"])
        record.rename("C2", to: "Docked")
        #expect(record.profiles == ["Docked", "B1"])
        counts["Docked"] = 2
        let stillBound = record.unbind(count: 2) { counts[$0] }
        #expect(!stillBound)
        #expect(record.profiles == ["B1"])
        let emptied = record.unbind("B1")
        #expect(emptied)
        #expect(record.profiles.isEmpty)
    }

    /// A Desktop bound to the profile ALREADY live is answered
    /// from adoption state, never by re-reading its file on the
    /// swipe (#1245): with the file gone, the door neither
    /// reads nor logs.
    @Test("the live profile is not re-read at the binding door")
    func liveProfileIsNotReread() throws {
        defer { reset() }
        pinTopology()
        let core = try seeded(screens: 1)
        bind(core, "Laptop")
        #expect(core.profiles.currentName == "Laptop")
        try FileManager.default.removeItem(
            at: core.profiles.directory
                .appendingPathComponent("Laptop.json")
        )
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.applyDesktopBinding(in: NativeSpaces.desktopSnapshot())
        #expect(core.profiles.currentName == "Laptop")
        #expect(!log.contains { $0.contains("cannot load") })
        // The stand-down is for a live profile that FITS: with
        // the screens changed under it, the gate re-judges.
        connect(core, 2)
        core.applyDesktopBinding(in: NativeSpaces.desktopSnapshot())
        #expect(log.contains { $0.contains("cannot load") })
    }
}
