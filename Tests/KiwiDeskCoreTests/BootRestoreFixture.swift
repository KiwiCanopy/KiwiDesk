import AppKit
import CoreGraphics
import Foundation

@testable import KiwiDeskCore

/// Two processes of one desk (#930): A lays it out and writes
/// its session snapshot; B scans the same windows where A left
/// them and runs the boot tail from that snapshot. Animations
/// are reduced so every frame a pass issues reaches the
/// applier's `issued` tee.
///
/// Both display seams (#531) are pinned to the MAIN screen's own
/// visible frame rather than a fabricated one: the park resolves
/// each window's real screen (a `visibleBounds` exemption), so
/// any other pin makes the corner test disagree with the park.
/// Every assertion compares process B against process A on the
/// same host, so the host's size never reaches a verdict.
@MainActor
enum BootRestoreFixture {
    static let shown = SpaceID("1")
    static let hidden = SpaceID("2")

    /// One window as the scan finds it.
    struct Window {
        let id: WindowID
        let space: SpaceID
        var frame: CGRect
        var floating = false
    }

    /// A core on the host's main screen, both display seams
    /// pinned and both Spaces on it, `shown` active. Nil where
    /// the host has no screen.
    static func makeCore() -> KiwiCore? {
        guard let screen = NSScreen.main,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        let pinned = GeometryUtils.axVisibleFrame(of: screen)
        core.tiler.visibleBounds = { _ in pinned }
        core.tiler.allScreenBounds = { [pinned] }
        core.tiler.animation.reduceMotion = { true }
        core.state.apply(.displaysChanged([display]))
        core.state.workspaces.ensureSpace(shown)
        core.state.workspaces.ensureSpace(hidden)
        core.resolveSpaceDisplays(mainID: display.id)
        core.state.workspaces.activate(shown)
        return core
    }

    static func managed(_ window: Window) -> ManagedWindow {
        ManagedWindow(
            id: window.id,
            pid: pid_t(100 + window.id.raw),
            appName: "App\(window.id.raw)",
            frame: window.frame,
            isFloating: window.floating
        )
    }

    /// Process A's desk: `windows` filed in their Spaces in
    /// order. The caller sets modes and sizing, then `settle`s.
    static func processA(
        _ windows: [Window],
        configure: (KiwiCore) -> Void = { _ in }
    ) -> KiwiCore? {
        guard let core = makeCore() else { return nil }
        configure(core)
        for window in windows {
            core.state.apply(.windowCreated(managed(window)))
            core.state.workspaces.add(window.id, to: window.space)
        }
        return core
    }

    /// Retiles until nothing more is issued, folding every issued
    /// frame back into state as its AX echo; returns where each
    /// window was left.
    static func settle(_ core: KiwiCore) -> [WindowID: CGRect] {
        for _ in 0..<4 {
            let issued = record(core) { core.retile() }
            let moved = issued.filter {
                core.state.windows[$0.0]?.frame != $0.1
            }
            if moved.isEmpty { break }
            for (id, frame) in moved {
                core.state.apply(.windowMoved(id, frame))
            }
        }
        var left: [WindowID: CGRect] = [:]
        for window in core.state.windows.all {
            left[window.id] = window.frame
        }
        return left
    }

    /// Every frame `body` issued, in order.
    static func record(
        _ core: KiwiCore,
        _ body: () -> Void
    ) -> [(WindowID, CGRect)] {
        var issued: [(WindowID, CGRect)] = []
        core.tiler.applier.issued = { issued.append(($0, $1)) }
        body()
        core.tiler.applier.issued = { _, _ in }
        return issued
    }

    /// The snapshot as it crosses the process boundary: through
    /// the file's own encoder and decoder.
    static func crossed(_ snapshot: StateSnapshot) throws -> StateSnapshot {
        try JSONDecoder().decode(
            StateSnapshot.self,
            from: JSONEncoder().encode(snapshot)
        )
    }

    /// Process B: a fresh core scans `windows` at `left` in a
    /// scrambled order with event retiles deferred, as the boot
    /// scan does, then runs the boot tail. Returns every frame
    /// issued from the first scanned window on.
    static func processB(
        _ windows: [Window],
        left: [WindowID: CGRect],
        session: StateSnapshot,
        configure: (KiwiCore) -> Void = { _ in }
    ) -> (KiwiCore, [(WindowID, CGRect)])? {
        guard let core = makeCore() else { return nil }
        configure(core)
        let issued = record(core) {
            core.defersEventRetiles = true
            for window in scanOrder(windows) {
                var found = window
                found.frame = left[window.id] ?? window.frame
                core.handle(.windowCreated(managed(found)))
            }
            core.defersEventRetiles = false
            core.arrangeBootDesk(session: session)
        }
        return (core, issued)
    }

    /// AX order is not the arrangement: reversed, then the halves
    /// interleaved, so no Space's members arrive in their order.
    static func scanOrder(_ windows: [Window]) -> [Window] {
        let reversed = Array(windows.reversed())
        let half = (reversed.count + 1) / 2
        var order: [Window] = []
        for i in 0..<half {
            order.append(reversed[i])
            if i + half < reversed.count {
                order.append(reversed[i + half])
            }
        }
        return order
    }
}
