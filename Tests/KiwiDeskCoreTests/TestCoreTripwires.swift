import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `makeTestCore`'s nets under its app-list pin (#2289): a core
/// never attaches, or sends a frame to, an app other than the
/// test process — whatever route found it. Each refusal records
/// an issue, attributed to a test only where the call runs in
/// that test's task; the refusal holds either way.
@MainActor
func armForeignAppTripwires(_ core: KiwiCore) {
    let observe = core.eventLoop.makeObserver
    core.eventLoop.makeObserver = { pid in
        refusesForeignApp(pid, "attached") ? nil : observe(pid)
    }
    let resolve = core.tiler.applier.elementProvider
    core.tiler.applier.elementProvider = { id in
        guard let element = resolve(id) else { return nil }
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success
        else { return element }
        return refusesForeignApp(pid, "sent a frame to")
            ? nil : element
    }
}

/// True, with an issue, for a pid LaunchServices names as an app
/// other than this process; a fixture's unused pid is no app.
@MainActor
func refusesForeignApp(_ pid: pid_t, _ act: String) -> Bool {
    guard pid > 0, pid != getpid(),
        kill(pid, 0) == 0 || errno == EPERM,
        let app = NSRunningApplication(processIdentifier: pid)
    else { return false }
    let name = app.bundleIdentifier ?? "pid \(pid)"
    Issue.record("a test \(act) \(name) (#2289)")
    return true
}
