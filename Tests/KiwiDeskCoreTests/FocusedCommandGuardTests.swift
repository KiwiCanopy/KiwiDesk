import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The foreground-ownership preflight (#292): an implicit-focused
/// command fails closed — with no state mutation — unless the OS
/// frontmost app is KiwiDesk's focused managed window. The guard is
/// inert until `frontmostPIDProvider` is wired, so these tests
/// inject a stub (and, for the allow path, a real self observer).
@Suite("Focused-command foreground guard", .serialized)
@MainActor
struct FocusedCommandGuardTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-guard-\(UUID().uuidString)"
                )
        )
    }

    /// Adds a window owned by `pid` and confirms it is the focused
    /// managed window (window creation focuses it).
    @discardableResult
    private func addFocused(
        _ core: KiwiCore,
        pid: pid_t
    ) -> WindowID {
        let id = WindowID(1)
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: id, pid: pid, appName: "App")
            )
        )
        #expect(core.focusedWindow?.id == id)
        return id
    }

    /// Registers a real self observer so `observes(pid)` is true —
    /// the condition unit tests can't get from AX. Returns false if
    /// the platform declines the observer (then the caller skips
    /// the allow-path assertion rather than flaking).
    private func observe(_ core: KiwiCore, pid: pid_t) -> Bool {
        guard let observer = AXApplicationObserver(pid: pid) else {
            return false
        }
        core.eventLoop.observers[pid] = observer
        return true
    }

    @Test("Inert without a provider: focused command runs")
    func inertByDefault() {
        let core = makeCore()
        addFocused(core, pid: 1)
        // No provider wired (the unit-test default), so the guard
        // never engages and the command mutates as usual.
        #expect(core.execute("make_floating").isSuccess)
        #expect(core.state.windows[WindowID(1)]?.isFloating == true)
    }

    @Test("Blocks when the frontmost app is a different pid")
    func blocksOnFrontmostMismatch() {
        let core = makeCore()
        addFocused(core, pid: 1)
        core.frontmostPIDProvider = { 999 }
        let response = core.execute("make_floating")
        #expect(!response.isSuccess)
        #expect(
            response.error == "no managed window is currently focused"
        )
        // Fail closed = no mutation.
        #expect(core.state.windows[WindowID(1)]?.isFloating == false)
    }

    @Test("Blocks when foreground ownership is unknown (nil)")
    func blocksOnUnknownForeground() {
        let core = makeCore()
        addFocused(core, pid: 1)
        core.frontmostPIDProvider = { nil }
        #expect(!core.execute("make_floating").isSuccess)
        #expect(core.state.windows[WindowID(1)]?.isFloating == false)
    }

    @Test("Blocks when the pid is frontmost but unobserved")
    func blocksWhenUnobserved() {
        let core = makeCore()
        addFocused(core, pid: 42)
        // Frontmost matches, but the event loop owns no observer
        // for pid 42 — the app is not (or no longer) managed.
        core.frontmostPIDProvider = { 42 }
        let response = core.execute(
            "resize",
            args: [.string("x"), .number(100)]
        )
        #expect(!response.isSuccess)
    }

    @Test("Allows when the focused managed window owns the foreground")
    func allowsOnGenuineForeground() {
        let core = makeCore()
        let pid = getpid()
        addFocused(core, pid: pid)
        guard observe(core, pid: pid) else { return }
        core.frontmostPIDProvider = { pid }
        #expect(core.execute("make_floating").isSuccess)
        #expect(core.state.windows[WindowID(1)]?.isFloating == true)
    }

    @Test("Blocks when an ignored panel is latched for the pid")
    func blocksWhenPanelLatched() {
        let core = makeCore()
        let pid = getpid()
        addFocused(core, pid: pid)
        guard observe(core, pid: pid) else { return }
        core.frontmostPIDProvider = { pid }
        // The app's ignored panel took focus (Ghostty-style): the
        // managed main window is stale behind it.
        core.ignoredPanelActive.insert(pid)
        #expect(!core.execute("make_floating").isSuccess)
        #expect(core.state.windows[WindowID(1)]?.isFloating == false)
    }

    @Test("Unrestricted commands bypass the guard")
    func unrestrictedBypass() {
        let core = makeCore()
        addFocused(core, pid: 1)
        // Frontmost mismatches, yet a global setter still runs — it
        // does not act on the implicit focused window, so the guard
        // must not touch it.
        core.frontmostPIDProvider = { 999 }
        let response = core.execute(
            "set_gap_global",
            args: [.number(8)]
        )
        #expect(response.isSuccess)
        #expect(
            response.error != "no managed window is currently focused"
        )
    }
}
