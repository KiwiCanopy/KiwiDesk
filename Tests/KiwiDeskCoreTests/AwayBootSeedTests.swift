import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// The boot census (#1146): a window of an observed app on a
/// Desktop nobody shows joins the ledger — filed under the
/// snapshot's space, else the Desktop's remembered Space, else
/// unfiled — and an unobserved app's, a tracked one and one on a
/// shown Desktop do not.
@MainActor
@Suite("Boot seeds the away ledger", .serialized)
struct AwayBootSeedTests {
    private final class FakeObserver: AppObserving {
        var onNotification: @MainActor (String, AXUIElement) -> Void = {
            _,
            _ in
        }
        var needsRegistrationRepair = false
        func observe(window: AXUIElement) {}
        func repairRegistration() {}
        func invalidate() {}
    }

    private let observed: pid_t = 100
    private let stranger: pid_t = 200

    private func makeCore() -> KiwiCore {
        NativeSpaces.spacesOverride = [
            authoritySpace(1, display: "UUID-A", current: true),
            authoritySpace(4, display: "UUID-A"),
        ]
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        let core = makeAuthorityCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.ensureSpace("2")
        core.state.workspaces.activate("1")
        let loop = core.eventLoop
        loop.onLog = { _ in }
        loop.registersWorkspaceObservers = false
        loop.visiblePIDs = { [] }
        loop.applyAXMessagingTimeout = { _ in }
        loop.makeObserver = { _ in FakeObserver() }
        loop.readEnhancedUI = { _ in false }
        loop.writeEnhancedUI = { _, _ in }
        loop.writeManualAX = { _, _ in }
        loop.axWindows = { _ in [] }
        loop.activationPolicy = { _ in .regular }
        let apps = [
            RunningApp(
                pid: observed,
                activationPolicy: .regular,
                ref: AppRef(bundleID: "app.test.observed", name: "Observed")
            ),
            RunningApp(
                pid: stranger,
                activationPolicy: .regular,
                ref: AppRef(bundleID: "app.test.stranger", name: "Stranger")
            ),
        ]
        loop.runningApplications = { apps }
        // `attach` is inert on a stopped loop; the seed runs at
        // the boot tail, where the loop is running.
        loop.isRunning = true
        loop.attach(
            pid: observed,
            activationPolicy: .regular,
            ref: apps[0].ref,
            scanWindowsAtAttach: false
        )
        return core
    }

    private func host(
        _ space: SkyLight.SpaceID,
        pid: pid_t
    ) -> DesktopCensus.Host {
        DesktopCensus.Host(space: space, pid: pid, isUp: true)
    }

    @Test(
        "only an observed app's untracked window on an unshown Desktop"
    )
    func seedsTheRightWindows() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        core.state.windows.upsert(
            ManagedWindow(id: WindowID(3), pid: observed, appName: "Observed")
        )
        core.desktopMemory.readCensus = { _ in
            DesktopCensus(
                hosts: [
                    WindowID(7): self.host(4, pid: self.observed),
                    WindowID(8): self.host(4, pid: self.stranger),
                    WindowID(3): self.host(4, pid: self.observed),
                    WindowID(5): self.host(1, pid: self.observed),
                ],
                shown: [1]
            )
        }
        core.seedAwayWindows()
        #expect(Set(core.state.awayWindows.keys) == [WindowID(7)])
        let entry = core.state.awayWindows[WindowID(7)]
        #expect(entry?.appName == "Observed")
        #expect(entry?.appBundleID == "app.test.observed")
        #expect(entry?.nativeSpace == 4)
        // No snapshot, no Desktop memory: unfiled.
        #expect(core.state.rememberedSpace(of: WindowID(7)) == nil)
        #expect(core.deferred.isScheduled(.awayCensus))
    }

    @Test("the snapshot's space files it, else the Desktop's remembered Space")
    func filingOrder() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        core.state.remember(WindowID(7), in: "2")
        core.rememberVirtualSpace("1", leaving: 2)
        core.desktopMemory.readCensus = { _ in
            DesktopCensus(
                hosts: [
                    WindowID(7): self.host(4, pid: self.observed),
                    WindowID(9): self.host(4, pid: self.observed),
                ],
                shown: [1]
            )
        }
        core.seedAwayWindows()
        #expect(core.state.rememberedSpace(of: WindowID(7)) == "2")
        #expect(core.state.rememberedSpace(of: WindowID(9)) == "1")
    }

    @Test("no census seeds nothing")
    func noCensusSeedsNothing() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        core.desktopMemory.readCensus = { _ in nil }
        core.seedAwayWindows()
        #expect(core.state.awayWindows.isEmpty)
        #expect(!core.deferred.isScheduled(.awayCensus))
    }
}
