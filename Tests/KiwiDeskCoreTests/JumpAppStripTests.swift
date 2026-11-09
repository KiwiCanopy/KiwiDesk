import AppKit
import Testing

@testable import KiwiDeskCore

/// KiwiHub's app strip (#3135): the apps the Windows side lists,
/// most recently used first, an app's recency being its own
/// activation or its windows' latest focus on one tick. An app
/// activated with no row is listed with its bundle id so its pick
/// can reopen it; the app in front, KiwiDesk and an app with no
/// bundle id are not.
@Suite("KiwiHub app strip (#3135)", .serialized)
@MainActor
struct JumpAppStripTests {
    private func makeCore(apps: [RunningApp] = []) -> KiwiCore {
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        pinTwoDisplays()
        let core = makeTestCore()
        core.eventLoop.runningApplications = { apps }
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.activate("1")
        return core
    }

    private func track(_ core: KiwiCore, _ id: UInt32, pid: pid_t) {
        let window = ManagedWindow(
            id: WindowID(id),
            pid: pid,
            appName: "App \(pid)",
            appBundleID: "app.test.\(pid)"
        )
        core.state.apply(.windowCreated(window))
        core.state.workspaces.add(WindowID(id), to: SpaceID("1"))
    }

    private func app(
        _ pid: pid_t,
        bundle: String? = "",
        policy: NSApplication.ActivationPolicy = .regular
    ) -> RunningApp {
        RunningApp(
            pid: pid,
            activationPolicy: policy,
            ref: AppRef(
                bundleID: bundle == "" ? "app.test.\(pid)" : bundle,
                name: "A\(pid)"
            ),
            isHidden: false
        )
    }

    private func pids(_ core: KiwiCore) -> [pid_t] {
        core.jumpSnapshot().apps.map(\.pid)
    }

    @Test("an app's activation outranks an older window focus")
    func activationOrders() {
        let core = makeCore()
        defer { resetAuthorityOverrides() }
        track(core, 1, pid: 900_001)
        track(core, 2, pid: 900_002)
        core.state.stampFocusRecency(WindowID(1))
        core.state.stampFocusRecency(WindowID(2))
        #expect(pids(core) == [900_002, 900_001])
        core.state.stampAppRecency(900_001)
        #expect(pids(core) == [900_001, 900_002])
    }

    @Test("a window's focus counts for its app")
    func windowFocusOrders() {
        let core = makeCore()
        defer { resetAuthorityOverrides() }
        track(core, 1, pid: 900_001)
        track(core, 2, pid: 900_002)
        core.state.stampAppRecency(900_001)
        core.state.stampFocusRecency(WindowID(2))
        #expect(pids(core) == [900_002, 900_001])
    }

    @Test("an activated app with no row is listed to reopen")
    func emptyAppIsListed() {
        let core = makeCore(apps: [app(900_003)])
        defer { resetAuthorityOverrides() }
        track(core, 1, pid: 900_001)
        core.state.stampFocusRecency(WindowID(1))
        core.state.stampAppRecency(900_003)
        let apps = core.jumpSnapshot().apps
        #expect(apps.map(\.pid) == [900_003, 900_001])
        #expect(apps.first?.bundleID == "app.test.900003")
        #expect(apps.last?.bundleID == nil)
    }

    @Test("the app in front with no row is left out")
    func frontAppIsLeftOut() {
        let core = makeCore(apps: [app(900_003)])
        defer { resetAuthorityOverrides() }
        core.frontmostPIDProvider = { 900_003 }
        core.state.stampAppRecency(900_003)
        #expect(pids(core).isEmpty)
    }

    /// Each exclusion alone: a stamped app with no row that the
    /// strip leaves out, beside a control it keeps.
    @Test(
        "no bundle id, KiwiDesk itself and a non-regular app are left out",
        arguments: ["bundle", "own", "accessory"]
    )
    func exclusions(_ kind: String) {
        let pid: pid_t = kind == "own" ? getpid() : 900_005
        let excluded = app(
            pid,
            bundle: kind == "bundle" ? nil : "",
            policy: kind == "accessory" ? .accessory : .regular
        )
        let core = makeCore(apps: [excluded, app(900_006)])
        defer { resetAuthorityOverrides() }
        core.state.stampAppRecency(pid)
        core.state.stampAppRecency(900_006)
        #expect(pids(core) == [900_006])
    }

    @Test("an app's exit ends its stamp")
    func exitEndsTheStamp() {
        let core = makeCore()
        defer { resetAuthorityOverrides() }
        core.state.stampAppRecency(900_004)
        #expect(core.state.appRecency[900_004] != nil)
        core.state.apply(.appTerminated(pid: 900_004))
        #expect(core.state.appRecency[900_004] == nil)
    }

    @Test("the snapshot names the listed window focused last")
    func lastUsedIsNewestStamp() {
        let core = makeCore()
        defer { resetAuthorityOverrides() }
        track(core, 1, pid: 900_001)
        track(core, 2, pid: 900_002)
        #expect(core.jumpSnapshot().lastUsed == nil)
        core.state.stampFocusRecency(WindowID(2))
        core.state.stampFocusRecency(WindowID(1))
        core.state.stampAppRecency(900_002)
        #expect(core.jumpSnapshot().lastUsed == .window(WindowID(1)))
    }

    @Test("an unnamed process is no identity")
    func unnamedPidIsNotStamped() {
        let core = makeCore()
        defer { resetAuthorityOverrides() }
        core.state.stampAppRecency(-1)
        #expect(core.state.appRecency.isEmpty)
    }

    /// The bootstrap wiring: an activation the event loop reports
    /// stamps its app, so a strip opened after it ranks it first.
    @Test("an activation report stamps its app")
    func activationIsWired() {
        let core = makeCore()
        defer { resetAuthorityOverrides() }
        track(core, 1, pid: 900_001)
        track(core, 2, pid: 900_002)
        core.state.stampFocusRecency(WindowID(2))
        core.eventLoop.onAppActivated(
            AppActivation(pid: 900_001, bundleID: nil, launchedAt: nil)
        )
        #expect(pids(core) == [900_001, 900_002])
    }
}
