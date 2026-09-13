import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A Desktop binding fires only where its profile is saved for
/// the connected screen count (#1394). For any other count it
/// stands aside and the rungs below answer, on both doors that
/// load a binding and in the verdict that names one — which is
/// what settles #1332: a bound load always fits by count, so
/// neither door marks clean beside its apply and both read one
/// verdict from it.
///
/// Serialized: the topology overrides are process-global.
@Suite("Desktop binding screen-count gate (#1394)", .serialized)
@MainActor
struct DesktopBindingFitTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-fit-\(UUID().uuidString)"
                )
        )
    }

    /// A 100x100 display named `name`, fingerprint
    /// `"<name>:100x100"` (#531: pinned, never this machine's).
    private func display(_ id: UInt32, _ name: String) -> Display {
        Display(
            id: DisplayID(id),
            name: name,
            frame: CGRect(
                x: CGFloat(id) * 100,
                y: 0,
                width: 100,
                height: 100
            )
        )
    }

    private func connect(_ core: KiwiCore, _ count: Int) {
        for id in 0..<count {
            core.state.workspaces.upsertDisplay(
                display(UInt32(id + 1), "D\(id + 1)")
            )
        }
    }

    private func profile(
        _ name: String,
        monitors: [String]
    ) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: monitors)],
            isDefault: false,
            spaceModes: ["1": .bsp],
            settings: TilingSettings()
        )
    }

    private func live(_ core: KiwiCore) -> [String] {
        core.state.workspaces.allDisplays.map(\.fingerprint)
    }

    /// One main display whose current Desktop is number 1,
    /// stamped so the binding files under an identity (#1147).
    private func pinTopology() {
        NativeSpaces.spacesOverride = [
            NativeSpace(
                id: 11,
                displayUUID: "UUID-A",
                isCurrent: true,
                identity: DesktopIdentity(raw: "STAMP-1")
            )
        ]
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        NativeSpaces.activeSpaceIDOverride = 11
    }

    private func resetTopology() {
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

    /// Saves `profiles` and loads the last one explicitly, so the
    /// fixture starts on a KNOWN clean profile: `ProfileManager
    /// .save` makes its argument current, and a binding to the
    /// profile already current applies nothing.
    private func seed(
        _ core: KiwiCore,
        _ profiles: [Profile]
    ) throws {
        for profile in profiles {
            try core.profiles.save(profile)
        }
        core.execute(
            "load_profile",
            args: [.string(profiles[profiles.count - 1].name)]
        )
    }

    /// Two screens, a one-screen profile to bind, and "Desk"
    /// saved for exactly these displays and loaded clean.
    private func misfitCore() throws -> KiwiCore {
        let core = makeCore()
        connect(core, 2)
        try seed(
            core,
            [
                profile("Golden", monitors: ["Solo:100x100"]),
                profile("Desk", monitors: live(core)),
            ]
        )
        #expect(core.profiles.currentName == "Desk")
        return core
    }

    @Test("A monitor change lets a misfit binding stand aside")
    func monitorChangeStandsAside() throws {
        defer { resetTopology() }
        pinTopology()
        let core = try misfitCore()
        var log: [String] = []
        core.onLog = { log.append($0) }
        bind(core, "Golden")
        core.handleMonitorChange()
        #expect(core.profiles.currentName == "Desk")
        #expect(
            log.contains {
                $0.contains(
                    "monitor change: profile 'Golden' is for "
                        + "1 screen(s), 2 connected"
                )
            }
        )
    }

    @Test("The binding door lets a misfit binding stand aside")
    func bindingDoorStandsAside() throws {
        defer { resetTopology() }
        pinTopology()
        let core = try misfitCore()
        var log: [String] = []
        core.onLog = { log.append($0) }
        // The verb itself takes the binding door.
        bind(core, "Golden")
        #expect(core.profiles.currentName == "Desk")
        core.applyDesktopBinding(in: NativeSpaces.desktopSnapshot())
        #expect(core.profiles.currentName == "Desk")
        #expect(
            log.contains {
                $0.contains(
                    "Desktop 1: profile 'Golden' is for "
                        + "1 screen(s), 2 connected"
                )
            }
        )
    }

    @Test("The verdict mirrors the gate")
    func verdictMirrorsTheGate() throws {
        defer { resetTopology() }
        pinTopology()
        let core = try misfitCore()
        bind(core, "Golden")
        let snapshot = NativeSpaces.desktopSnapshot()
        #expect(
            core.profileVerdict(
                activeBinding: core.mainDesktopBinding(in: snapshot)
            ).verdict == .exactMonitors(name: "Desk")
        )
    }

    @Test("A fitting binding loads on both doors")
    func fittingBindingLoads() throws {
        defer { resetTopology() }
        pinTopology()
        let core = makeCore()
        connect(core, 2)
        try seed(
            core,
            [
                profile("Duo", monitors: live(core)),
                // Same count, other monitors: an exact match
                // cannot pick "Duo" by ordering luck.
                profile("Other", monitors: ["X:1x1", "Y:1x1"]),
            ]
        )
        bind(core, "Duo")
        #expect(core.profiles.currentName == "Duo")
        #expect(!core.profiles.isDirty)
        core.execute("load_profile", args: [.string("Other")])
        #expect(core.profiles.currentName == "Other")
        core.handleMonitorChange()
        #expect(core.profiles.currentName == "Duo")
        #expect(!core.profiles.isDirty)
    }

    /// The #1332 agreement: a profile of the right count but for
    /// other monitors is dirty on BOTH doors — the apply's own
    /// verdict, which the binding door used to overrule.
    @Test("Both doors agree on a profile saved for other monitors")
    func doorsAgreeOnOtherMonitors() throws {
        defer { resetTopology() }
        pinTopology()
        let core = makeCore()
        connect(core, 2)
        try seed(
            core,
            [
                profile("Away", monitors: ["X:1x1", "Y:1x1"]),
                profile("Other", monitors: live(core)),
            ]
        )
        #expect(!core.profiles.isDirty)
        bind(core, "Away")
        #expect(core.profiles.currentName == "Away")
        #expect(core.profiles.isDirty)
        core.execute("load_profile", args: [.string("Other")])
        #expect(!core.profiles.isDirty)
        core.handleMonitorChange()
        #expect(core.profiles.currentName == "Away")
        #expect(core.profiles.isDirty)
    }

    /// No displays known — the first config load, a paused
    /// engine — cannot judge, so the binding waits for the first
    /// display reading, which the boot scan's monitor change is.
    @Test("Unknown displays make the binding wait")
    func unknownDisplaysMakeItWait() throws {
        defer { resetTopology() }
        pinTopology()
        let core = makeCore()
        try seed(
            core,
            [
                profile("Golden", monitors: ["Solo:100x100"]),
                profile("Other", monitors: ["Z:1x1"]),
            ]
        )
        #expect(core.profiles.currentName == "Other")
        var log: [String] = []
        core.onLog = { log.append($0) }
        bind(core, "Golden")
        #expect(core.profiles.currentName == "Other")
        #expect(
            log.contains {
                $0.contains(
                    "profile 'Golden' waits for the first display"
                )
            }
        )
        connect(core, 1)
        core.handleMonitorChange()
        #expect(core.profiles.currentName == "Golden")
    }

    /// An in-effect edit's hot-reload asks the same gate: a
    /// standing-aside binding is not on screen.
    @Test("A standing-aside binding is not in effect")
    func standingAsideIsNotInEffect() throws {
        defer { resetTopology() }
        pinTopology()
        let core = try misfitCore()
        bind(core, "Golden")
        #expect(!core.isProfileInEffect("Golden"))
        #expect(core.isProfileInEffect("Desk"))
        core.execute("load_profile", args: [.string("Golden")])
        #expect(core.isProfileInEffect("Golden"))
    }
}
