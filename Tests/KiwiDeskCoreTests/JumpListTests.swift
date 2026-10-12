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

    /// Tracked, away and minimized rows ranked together: one
    /// recency order across all three, never per kind.
    @Test("recency interleaves tracked, away and minimized rows")
    func recencyAcrossKinds() {
        let core = makeCore()
        defer { resetAuthorityOverrides() }
        track(core, 1, title: "here")
        track(core, 7, title: "away", in: "2")
        track(core, 4, title: "parked")
        core.state.stampFocusRecency(WindowID(7))
        core.state.stampFocusRecency(WindowID(1))
        core.state.stampFocusRecency(WindowID(4))
        core.state.rememberedSpaces[WindowID(7)] = .departed("2")
        core.recordAwayWindow(
            WindowID(7),
            removed: core.state.removalFacts(WindowID(7)),
            nativeSpace: 11
        )
        core.state.windows.remove(WindowID(7))
        core.state.workspaces.remove(WindowID(7))
        var effects = AppliedEffects()
        core.state.applyWindowDestroyed(
            WindowID(4),
            wasMinimized: true,
            effects: &effects
        )
        #expect(windows(core.jumpEntries()) == [4, 1, 7])
    }

    @Test("the snapshot names the Space the user is in")
    func snapshotNamesHere() {
        let core = makeCore()
        defer { resetAuthorityOverrides() }
        core.tiler.settings.spaceIcons[SpaceID("1")] = "house"
        let snapshot = core.jumpSnapshot()
        #expect(snapshot.here == "1")
        #expect(snapshot.hereIcon == .symbol("house"))
    }

    /// The bar chip's reading: a held Space keeps its icon.
    @Test("a held Space's row carries the icon its chip shows")
    func heldSpaceIcon() {
        let core = makeCore()
        defer { resetAuthorityOverrides() }
        core.state.heldSpaces[SpaceID("2")] = HeldOrigin(
            name: SpaceID("3"),
            screen: "DELL:2560x1440",
            icon: "star",
            arrangement: .profile("Desk")
        )
        track(core, 1, title: "held", in: "2")
        #expect(core.jumpEntries().first?.spaceIcon == .symbol("star"))
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

    /// The gone handler's own filing, from the removal facts.
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

    /// A window closed while minimized fires no event: the record
    /// the WindowServer no longer lists is left out.
    @Test("a stale minimize record is not listed")
    func staleMinimizedLeftOut() {
        let core = makeCore()
        defer { resetAuthorityOverrides() }
        track(core, 4, title: "live")
        track(core, 5, title: "closed")
        var effects = AppliedEffects()
        for id in [4, 5] as [UInt32] {
            core.state.applyWindowDestroyed(
                WindowID(id),
                wasMinimized: true,
                effects: &effects
            )
        }
        core.jump.knownWindows = { [WindowID(4)] }
        #expect(windows(core.jumpEntries()) == [4])
        core.jump.knownWindows = { nil }
        #expect(Set(windows(core.jumpEntries())) == [4, 5])
    }

    @Test("hidden regular apps come last, one row each, by name")
    func hiddenApps() {
        let app:
            (pid_t, String, NSApplication.ActivationPolicy, Bool)
                -> RunningApp = { pid, name, policy, hidden in
                    RunningApp(
                        pid: pid,
                        activationPolicy: policy,
                        ref: AppRef(bundleID: "app.test.\(pid)", name: name),
                        isHidden: hidden
                    )
                }
        let apps = [
            app(300, "Spotify", .regular, true),
            app(301, "Mail", .regular, false),
            app(303, "Calendar", .regular, true),
            app(302, "Agent", .accessory, true),
            app(getpid(), "KiwiDesk", .regular, true),
        ]
        let core = makeCore(apps: apps)
        defer { resetAuthorityOverrides() }
        core.eventLoop.activationPolicy = { pid in
            apps.first { $0.pid == pid }?.activationPolicy
        }
        track(core, 1, title: "a")
        let rows = core.jumpEntries()
        #expect(windows(rows) == [1])
        #expect(
            rows.dropFirst().map(\.target)
                == [.hiddenApp(303), .hiddenApp(300)]
        )
        #expect(rows.last?.app == "Spotify")
    }

    /// Nothing a row does reaches the window the user is in, so it
    /// is no row (owner, 2026-10-12): the list starts at the
    /// previous window.
    @Test("the focused window is left out")
    func focusedLeftOut() {
        let core = makeCore()
        defer { resetAuthorityOverrides() }
        track(core, 1, title: "a")
        track(core, 2, title: "b")
        core.frontmostPIDProvider = { 100 }
        core.state.workspaces.focus(WindowID(2), in: "1")
        #expect(windows(core.jumpEntries()) == [1])
        core.state.workspaces.focus(WindowID(1), in: "1")
        #expect(windows(core.jumpEntries()) == [2])
    }

    /// The last tracked focus is no longer the window the user is
    /// in once another app is in front: it stays a row.
    @Test("a stale focus under another app stays a row")
    func staleFocusStays() {
        let core = makeCore()
        defer { resetAuthorityOverrides() }
        track(core, 1, title: "a")
        track(core, 2, title: "b")
        core.state.workspaces.focus(WindowID(2), in: "1")
        core.frontmostPIDProvider = { 999 }
        #expect(Set(windows(core.jumpEntries())) == [1, 2])
    }
}
