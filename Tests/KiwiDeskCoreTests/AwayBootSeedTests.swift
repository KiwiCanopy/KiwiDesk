import AppKit
import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

/// The boot census (#1146): a window of an observed app on a
/// Desktop nobody shows joins the ledger — filed under the
/// snapshot's space, else the Desktop's remembered Space, else
/// unfiled — and an unobserved app's, a tracked one, one on a
/// shown Desktop and a PARKED one do not. A window on a hidden
/// full-screen Space joins it unfiled (#2949).
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
            authoritySpace(9, display: "UUID-A", isUser: false),
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

    @Test("a parked window is not seeded")
    func skipsParked() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        core.desktopMemory.readCensus = { _ in
            DesktopCensus(
                hosts: [
                    WindowID(7): DesktopCensus.Host(
                        space: 4,
                        pid: self.observed,
                        isUp: false
                    ),
                    WindowID(8): self.host(4, pid: self.observed),
                ],
                shown: [1]
            )
        }
        core.seedAwayWindows()
        // The UP sibling proves the fixture reaches the seed at
        // all, so the skip is a decision rather than an empty run.
        #expect(Set(core.state.awayWindows.keys) == [WindowID(8)])
    }

    @Test("an all-parked census leaves the task unarmed")
    func allParkedArmsNothing() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        core.desktopMemory.readCensus = { _ in
            DesktopCensus(
                hosts: [
                    WindowID(7): DesktopCensus.Host(
                        space: 4,
                        pid: self.observed,
                        isUp: false
                    )
                ],
                shown: [1]
            )
        }
        core.seedAwayWindows()
        // The reported harm (#1234): a seeded parked window can
        // never be pruned, so the ledger never empties and the
        // 5 s census re-arms for the life of the process.
        #expect(core.state.awayWindows.isEmpty)
        #expect(!core.deferred.isScheduled(.awayCensus))
    }

    @Test("the snapshot's space files it, else the Desktop's remembered Space")
    func filingOrder() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        core.state.remember(WindowID(7), in: "2")
        core.rememberVirtualSpace("1", leaving: .number(2))
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

    /// The carried filing resumes as the departure it was, so its
    /// return takes its slot (#2907) — an app not yet observed
    /// included, whose window the ledger does not take; a plain
    /// filing and a parked window stay filings.
    @Test("a carried filing on an away Desktop resumes its departure")
    func carriedFilingResumes() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        let carried = [WindowID(7), WindowID(8), WindowID(6)]
        core.state.refilePending(carried, in: "2")
        core.state.remember(WindowID(9), in: "2")
        core.desktopMemory.readCensus = { _ in
            DesktopCensus(
                hosts: [
                    WindowID(7): self.host(4, pid: self.observed),
                    WindowID(8): self.host(4, pid: self.stranger),
                    WindowID(6): DesktopCensus.Host(
                        space: 4,
                        pid: self.observed,
                        isUp: false
                    ),
                    WindowID(9): self.host(4, pid: self.observed),
                ],
                shown: [1]
            )
        }
        core.seedAwayWindows()
        #expect(core.state.rememberedSpaces[WindowID(7)] == .departed("2"))
        #expect(core.state.rememberedSpaces[WindowID(8)] == .departed("2"))
        #expect(core.state.rememberedSpaces[WindowID(6)] == .restored("2"))
        #expect(core.state.rememberedSpaces[WindowID(9)] == .restored("2"))
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

    /// Space 9 is a full-screen Space no screen shows: its census
    /// names the windows the user Desktops' `hosts` never lists.
    private func fullScreenCensus() -> DesktopCensus {
        DesktopCensus(
            hosts: [:],
            shown: [1],
            fullScreen: [9],
            hiddenFullScreenHosts: [
                WindowID(7): host(9, pid: observed),
                WindowID(8): host(9, pid: stranger),
                WindowID(3): host(9, pid: observed),
                WindowID(6): DesktopCensus.Host(
                    space: 9,
                    pid: observed,
                    isUp: false
                ),
            ]
        )
    }

    @Test("a window on a hidden full-screen Space is seeded unfiled")
    func seedsFullScreenUnfiled() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        core.state.windows.upsert(
            ManagedWindow(id: WindowID(3), pid: observed, appName: "Observed")
        )
        core.desktopMemory.readCensus = { _ in self.fullScreenCensus() }
        core.seedAwayWindows()
        // The observed app's untracked UP window alone: no stranger,
        // no tracked window, no parked one.
        #expect(Set(core.state.awayWindows.keys) == [WindowID(7)])
        let entry = core.state.awayWindows[WindowID(7)]
        #expect(entry?.nativeSpace == 9)
        #expect(entry?.appName == "Observed")
        #expect(entry?.title == "")
        // A full-screen-only seed still arms the census.
        #expect(core.deferred.isScheduled(.awayCensus))
        // KiwiHub lists it by app name, as full screen, in no Space.
        let row = core.jumpEntries().first {
            $0.target == .window(WindowID(7))
        }
        #expect(row?.app == "Observed")
        #expect(row?.status == .fullscreen)
        #expect(row?.space == nil)
    }

    /// The full-screen arm shares the Desktop arm's admission: a
    /// carried filing resumes as the departure it was (#2907), an
    /// unobserved app's included; a parked one (its app hidden)
    /// stays a filing.
    @Test("a carried filing on a hidden full-screen Space resumes")
    func fullScreenResumesCarried() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        let carried = [WindowID(7), WindowID(8), WindowID(6)]
        core.state.refilePending(carried, in: "2")
        core.desktopMemory.readCensus = { _ in self.fullScreenCensus() }
        core.seedAwayWindows()
        #expect(core.state.rememberedSpaces[WindowID(7)] == .departed("2"))
        #expect(core.state.rememberedSpaces[WindowID(8)] == .departed("2"))
        #expect(core.state.rememberedSpaces[WindowID(6)] == .restored("2"))
        #expect(core.state.awayWindows[WindowID(7)]?.nativeSpace == 9)
    }

    @Test("the census prune keeps a seeded full-screen entry")
    func pruneKeepsFullScreenSeed() {
        defer { resetAuthorityOverrides() }
        let core = makeCore()
        core.desktopMemory.readCensus = { _ in self.fullScreenCensus() }
        core.seedAwayWindows()
        let empty = DesktopCensus(hosts: [:], shown: [1], fullScreen: [9])
        core.desktopMemory.readCensus = { _ in empty }
        core.desktopMemory.readWindowSpace = { _ in .hosted(9) }
        core.refreshAwayWindows()
        #expect(core.state.awayWindows[WindowID(7)]?.nativeSpace == 9)
        // Closed while away: the same prune ends it.
        core.desktopMemory.readWindowSpace = { _ in .gone }
        core.refreshAwayWindows()
        #expect(core.state.awayWindows[WindowID(7)] == nil)
    }
}
