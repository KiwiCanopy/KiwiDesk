import ApplicationServices
import CoreGraphics
import Foundation

/// The AX writes the frame queues perform. Live by default; a
/// test swaps it to count the calls a pass costs (#1508).
struct FrameWriter: Sendable {
    var setFrame: @Sendable (CGRect, AXUIElement) -> Void
    var setPosition: @Sendable (CGPoint, AXUIElement) -> Void
    var writeEUI: @Sendable (pid_t, Bool) -> Void

    static let live = FrameWriter(
        setFrame: { WindowControl.setFrame($0, of: $1) },
        setPosition: { WindowControl.setPosition($0, of: $1) },
        writeEUI: {
            AXHelper.setEnhancedUserInterface(pid: $0, enabled: $1)
        }
    )
}

/// Who holds an app's `AXEnhancedUserInterface` off (#881,
/// #1508): an animation of one of its windows, or a run of
/// instant sets queued back to back. The flag drops when the
/// first hold starts and returns when the last ends, so a batch
/// of N instant sets costs two toggles rather than 2N.
///
/// Whether the flag is ON at rest is the event loop's fact
/// (`enhancedUIBaselines`, warmed on): it is handed in at each
/// enqueue and at the loop's retirement of the app, never read
/// or cached here. An app the loop has not warmed — Chromium,
/// a cold app — is never toggled.
///
/// `noteAtRest`, `noteInstantQueued` and `retire` run on the
/// main actor; every other method on the app's own serial frame
/// queue, which orders a toggle against the sets it brackets.
final class EnhancedUIHolds: @unchecked Sendable {
    private struct App {
        var atRest = false
        var dropped = false
        var holders = 0
        var queuedInstants = 0
        var instantHeld = false

        var idle: Bool {
            holders == 0 && queuedInstants == 0 && !instantHeld
        }
    }

    private let lock = NSLock()
    private var apps: [pid_t: App] = [:]

    private func with<T>(_ body: (inout [pid_t: App]) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(&apps)
    }

    /// Main actor, at enqueue: the loop's current at-rest value.
    func noteAtRest(_ pid: pid_t, _ on: Bool) {
        with { $0[pid, default: App()].atRest = on }
    }

    /// Main actor, when the loop stops owning the app: the value
    /// it left the flag at, which a hold still open restores.
    func retire(_ pid: pid_t, leftOn: Bool) {
        with { apps in
            guard var app = apps[pid] else { return }
            app.atRest = leftOn
            apps[pid] = app.idle ? nil : app
        }
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
        let drops = with { apps -> Bool in
            var app = apps[pid, default: App()]
            app.holders += 1
            defer { apps[pid] = app }
            guard app.holders == 1, app.atRest else { return false }
            app.dropped = true
            return true
        }
        if drops { writer.writeEUI(pid, false) }
    }

    func release(_ pid: pid_t, _ writer: FrameWriter) {
        let restores = with { apps -> Bool in
            guard var app = apps[pid], app.holders > 0
            else { return false }
            app.holders -= 1
            guard app.holders == 0 else {
                apps[pid] = app
                return false
            }
            let restores = app.dropped && app.atRest
            app.dropped = false
            apps[pid] = app.idle ? nil : app
            return restores
        }
        if restores { writer.writeEUI(pid, true) }
    }
}
