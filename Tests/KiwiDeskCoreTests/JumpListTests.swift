import AppKit
import Testing

@testable import KiwiDeskCore

/// The rows Jump to window lists (#1875): tracked windows, away
/// ones that are up, minimized ones — most recently used first —
/// then one row per hidden regular app. The topology is the #888
/// fixture: Desktops 1–2 on `UUID-A` (ids 10, 11).
@Suite("Jump to window rows (#1875)", .serialized)
@MainActor
struct JumpListTests {
    private func makeCore(apps: [RunningApp] = []) -> KiwiCore {
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        pinTwoDisplays()
        let core = makeTestCore()
        core.eventLoop.runningApplications = { apps }
        core.eventLoop.appIsHidden = { $0 == 300 }
        for space in ["1", "2"] {
            core.state.workspaces.ensureSpace(SpaceID(space))
        }
        core.state.workspaces.activate("1")
        return core
    }

    private func track(
        _ core: KiwiCore,
        _ id: UInt32,
        title: String,
        in space: String = "1",
        configure: (inout ManagedWindow) -> Void = { _ in }
    ) {
        var window = ManagedWindow(
            id: WindowID(id),
            pid: 100,
            appName: "Notes",
            appBundleID: "app.test.notes"
        )
        window.title = title
        configure(&window)
        core.state.apply(.windowCreated(window))
        core.state.workspaces.add(WindowID(id), to: SpaceID(space))
    }

    private func windows(_ rows: [JumpEntry]) -> [UInt32] {
        rows.compactMap {
            guard case .window(let id) = $0.target else { return nil }
            return id.raw
        }
    }

    @Test("the most recently focused window comes first")
    func recencyOrders() {
        let core = makeCore()
        defer { resetAuthorityOverrides() }
        track(core, 1, title: "a")
        track(core, 2, title: "b", in: "2")
        track(core, 3, title: "c")
        core.state.stampFocusRecency(WindowID(1))
        core.state.stampFocusRecency(WindowID(3))
        #expect(windows(core.jumpEntries()) == [3, 1, 2])
    }

    @Test("a row names its Space, its icon and its state")
    func rowFacts() {
        let core = makeCore()
        defer { resetAuthorityOverrides() }
        core.tiler.settings.spaceIcons[SpaceID("2")] = "terminal"
        track(core, 1, title: "plain")
        track(core, 2, title: "full", in: "2") { $0.isFullscreen = true }
        let rows = core.jumpEntries()
        let plain = rows.first { $0.title == "plain" }
        let full = rows.first { $0.title == "full" }
        #expect(plain?.space == "1")
        #expect(plain?.spaceIcon == nil)
        #expect(plain?.status == .shown)
        #expect(full?.space == "2")
        #expect(full?.spaceIcon == .symbol("terminal"))
        #expect(full?.status == .fullscreen)
    }

    @Test("a transient overlay is never listed")
    func overlaysLeftOut() {
        let core = makeCore()
        defer { resetAuthorityOverrides() }
        track(core, 1, title: "menu") { $0.isTransientOverlay = true }
        #expect(core.jumpEntries().isEmpty)
    }

    /// Through the real fold: the title is kept at the departure.
    @Test("an away window keeps its title, Space and Desktop")
    func awayRow() {
        let core = makeCore()
        defer { resetAuthorityOverrides() }
        track(core, 7, title: "draft", in: "2")
        let removed = core.state.removalFacts(WindowID(7))
        core.state.rememberedSpaces[WindowID(7)] = .departed("2")
        core.recordAwayWindow(
            WindowID(7),
            removed: removed,
            nativeSpace: 11
        )
        core.state.windows.remove(WindowID(7))
        core.state.workspaces.remove(WindowID(7))
        let row = core.jumpEntries().first
        #expect(row?.title == "draft")
        #expect(row?.space == "2")
        #expect(row?.status == .away(desktop: 2))
    }

    @Test("an away window parked on its Desktop is not listed")
    func parkedAwayLeftOut() {
        let core = makeCore()
        defer { resetAuthorityOverrides() }
        core.state.awayWindows[WindowID(7)] = AwayWindow(
            id: WindowID(7),
            pid: 100,
            appName: "Notes",
            appBundleID: nil,
            nativeSpace: 11,
            isUp: false
        )
        #expect(core.jumpEntries().isEmpty)
    }

    /// Through the real destroy fold's minimize arm.
    @Test("a minimized window is listed by its title")
    func minimizedRow() {
        let core = makeCore()
        defer { resetAuthorityOverrides() }
        track(core, 4, title: "parked")
        var effects = AppliedEffects()
        core.state.applyWindowDestroyed(
            WindowID(4),
            wasMinimized: true,
            effects: &effects
        )
        let row = core.jumpEntries().first
        #expect(row?.target == .window(WindowID(4)))
        #expect(row?.title == "parked")
        #expect(row?.app == "Notes")
        #expect(row?.status == .minimized)
    }

    @Test("hidden regular apps come last, one row each, by name")
    func hiddenApps() {
        let apps = [
            RunningApp(
                pid: 300,
                activationPolicy: .regular,
                ref: AppRef(bundleID: "app.test.spotify", name: "Spotify")
            ),
            RunningApp(
                pid: 301,
                activationPolicy: .regular,
                ref: AppRef(bundleID: "app.test.mail", name: "Mail")
            ),
            RunningApp(
                pid: 302,
                activationPolicy: .accessory,
                ref: AppRef(bundleID: "app.test.agent", name: "Agent")
            ),
        ]
        let core = makeCore(apps: apps)
        defer { resetAuthorityOverrides() }
        core.eventLoop.appIsHidden = { $0 != 301 }
        track(core, 1, title: "a")
        let rows = core.jumpEntries()
        #expect(rows.count == 2)
        #expect(rows.last?.target == .hiddenApp(300))
        #expect(rows.last?.status == .hidden)
        #expect(rows.last?.app == "Spotify")
    }
}
