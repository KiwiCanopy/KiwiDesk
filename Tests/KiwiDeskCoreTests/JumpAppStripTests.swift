import AppKit
import Testing

@testable import KiwiDeskCore

/// KiwiHub's app strip (#3135): the apps the Windows side lists,
/// most recently used first, an app's recency being its own
/// activation or its windows' latest focus on one tick. An app
/// with no listed window has no tile (#3168).
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

    /// The ruling reversed on #3168: a running app with no listed
    /// window has no tile, whatever its stamp, beside a control
    /// that keeps one.
    @Test("an activated app with no row has no tile")
    func emptyAppIsLeftOut() {
        let core = makeCore(apps: [app(900_003)])
        defer { resetAuthorityOverrides() }
        track(core, 1, pid: 900_001)
        core.state.stampFocusRecency(WindowID(1))
        core.state.stampAppRecency(900_003)
        #expect(pids(core) == [900_001])
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
