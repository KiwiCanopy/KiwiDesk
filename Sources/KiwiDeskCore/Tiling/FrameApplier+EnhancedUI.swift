import ApplicationServices
import CoreGraphics
import Foundation

/// The AX writes the frame queues perform. Live by default; a
/// test swaps it to count the calls a pass costs (#1508).
struct FrameWriter: Sendable {
    var setFrame: @Sendable (CGRect, AXUIElement) -> Void
    var setPosition: @Sendable (CGPoint, AXUIElement) -> Void
    var readEUI: @Sendable (pid_t) -> Bool?
    var writeEUI: @Sendable (pid_t, Bool) -> Void

    static let live = FrameWriter(
        setFrame: { WindowControl.setFrame($0, of: $1) },
        setPosition: { WindowControl.setPosition($0, of: $1) },
        readEUI: { AXHelper.getEnhancedUserInterface(pid: $0) },
        writeEUI: {
            AXHelper.setEnhancedUserInterface(pid: $0, enabled: $1)
        }
    )
}

/// Who holds an app's `AXEnhancedUserInterface` off (#881,
/// #1508): an animation of one of its windows, or a run of
/// instant sets queued back to back. The flag drops when the
/// first hold starts and returns when the last ends, so a batch
/// of N instant sets costs two toggles rather than 2N, and the
/// at-rest value is read once per app rather than per set.
///
/// Every method but `noteInstantQueued` runs on the app's own
/// serial frame queue, which is what orders a toggle against
/// the sets it brackets. Only an ANSWERED read is cached: an app
/// that does not answer (Chromium, or a read that timed out)
/// is never toggled and is asked again at its next hold.
final class EnhancedUIHolds: @unchecked Sendable {
    private struct App {
        var atRest: Bool?
        var holders = 0
        var queuedInstants = 0
        var instantHeld = false
    }

    private let lock = NSLock()
    private var apps: [pid_t: App] = [:]

    private func with<T>(_ body: (inout [pid_t: App]) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(&apps)
    }

    /// Main actor, at enqueue: an instant set is on its way, so
    /// the one ahead of it keeps the flag down.
    func noteInstantQueued(_ pid: pid_t) {
        with { $0[pid, default: App()].queuedInstants += 1 }
    }

    /// Ahead of an instant set: joins the running batch or opens
    /// one.
    func beginInstant(_ pid: pid_t, _ writer: FrameWriter) {
        let opens = with { apps -> Bool in
            var app = apps[pid, default: App()]
            app.queuedInstants -= 1
            defer { apps[pid] = app }
            guard !app.instantHeld else { return false }
            app.instantHeld = true
            return true
        }
        if opens { acquire(pid, writer) }
    }

    /// After an instant set: closes the batch once no other
    /// instant set is queued behind it.
    func endInstant(_ pid: pid_t, _ writer: FrameWriter) {
        let closes = with { apps -> Bool in
            guard var app = apps[pid], app.instantHeld,
                app.queuedInstants <= 0
            else { return false }
            app.instantHeld = false
            apps[pid] = app
            return true
        }
        if closes { release(pid, writer) }
    }

    func acquire(_ pid: pid_t, _ writer: FrameWriter) {
        let state = with { apps -> (first: Bool, atRest: Bool?) in
            apps[pid, default: App()].holders += 1
            let app = apps[pid]!
            return (app.holders == 1, app.atRest)
        }
        guard state.first else { return }
        var atRest = state.atRest
        if atRest == nil {
            atRest = writer.readEUI(pid)
            if let atRest {
                with { $0[pid]?.atRest = atRest }
            }
        }
        if atRest == true { writer.writeEUI(pid, false) }
    }

    func release(_ pid: pid_t, _ writer: FrameWriter) {
        let restores = with { apps -> Bool in
            guard var app = apps[pid], app.holders > 0
            else { return false }
            app.holders -= 1
            apps[pid] = app
            return app.holders == 0 && app.atRest == true
        }
        if restores { writer.writeEUI(pid, true) }
    }

    /// A terminated app's pid may be reused by a process whose
    /// flag nobody has read.
    func forget(_ pid: pid_t) {
        with { $0[pid] = nil }
    }
}
