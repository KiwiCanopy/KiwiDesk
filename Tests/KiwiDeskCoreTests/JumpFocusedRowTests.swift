import AppKit
import Testing

@testable import KiwiDeskCore

/// The focused window is no row of Jump to window (#1875 ▸ owner,
/// 2026-10-12) — only while its app, or a sibling process of it
/// (#1785), is the one in front. Split from `JumpListTests`.
@Suite("Jump to window's focused row (#1875)", .serialized)
@MainActor
struct JumpFocusedRowTests {
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

    /// A sibling process announced in front (#1785) is the same
    /// app: its focused window is still the one the user is in.
    @Test("the focused window is left out under a sibling process")
    func focusedLeftOutUnderSibling() {
        let core = makeCore()
        defer { resetAuthorityOverrides() }
        track(core, 1, title: "a")
        track(core, 2, title: "b")
        let family = AppRef(bundleID: "app.test.notes", name: "Notes")
        let sibling: pid_t = 178_903
        core.eventLoop.processIdentity.appAt = { asked in
            asked == 100
                ? RunningApp(pid: 100, activationPolicy: .regular, ref: family)
                : nil
        }
        core.eventLoop.processIdentity.record(
            RunningApp(pid: sibling, activationPolicy: .regular, ref: family)
        )
        core.frontmostPIDProvider = { sibling }
        core.state.workspaces.focus(WindowID(2), in: "1")
        #expect(windows(core.jumpEntries()) == [1])
    }
}
