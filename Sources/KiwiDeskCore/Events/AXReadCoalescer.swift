import ApplicationServices
import CoreGraphics
import Foundation

/// Coalesces asynchronous AX reads off the main actor (#618):
/// the frame behind a move/resize notification, the liveness
/// frame behind a focus report, the title behind a title
/// notification (#1088) and the window list behind an
/// event-driven reconcile (#1930). Per-PID serial reads keep one slow app
/// from blocking the main thread (`FrameApplier`). Two residuals
/// are accepted: an event can deliver after its window's
/// destroy, and `trackedFrames` can lag by one read — draining
/// pending reads before a reconcile would re-block the main
/// actor, the cost this type exists to remove.
@MainActor
final class AXReadCoalescer {
    /// The frame reads, keyed apart so a kind never coalesces
    /// against another's answer.
    enum Kind: Hashable, Sendable {
        case moved
        case resized
        /// Post-settle frame probe (#677).
        case settleProbe
    }

    /// One serial queue per app per lane, so a focus report is
    /// never parked behind that app's frame storm (#1088,
    /// input-and-animation.md).
    private enum Lane: Hashable {
        case frames
        case focus
        case titles
        case windowList
    }

    private enum Key: Hashable, Sendable {
        case frame(WindowID, Kind)
        /// One per APP, never per window: the focus stream is
        /// single-valued, so newest-wins collapses ACROSS
        /// windows (#1088, input-and-animation.md).
        case focus(pid_t)
        case title(WindowID)
        /// One per app. A request landing mid-read joins the
        /// next read rather than replacing its waiter: every
        /// waiter is a reconcile owed, and a read that began
        /// before the request cannot answer it (#1930).
        case windowList(pid_t)

        var lane: Lane {
            switch self {
            case .frame: .frames
            case .focus: .focus
            case .title: .titles
            case .windowList: .windowList
            }
        }
    }

    /// What one read answered — the key decides which.
    /// Unchecked for the window list alone: an `AXUIElement` is
    /// an immutable CF reference, safe to hand across threads.
    private enum Reading: @unchecked Sendable {
        case frame(CGRect)
        case title(String?)
        case windowList([AXUIElement])
    }

    private struct Pending {
        let pid: pid_t
        /// The blocking read, run OFF the main actor.
        let read: @Sendable () -> Reading
        let onReading: @MainActor (Reading) -> Void
    }

    private struct QueueKey: Hashable {
        let pid: pid_t
        let lane: Lane
    }

    /// The blocking AX frame read, called OFF the main actor.
    var reader: @Sendable (AXUIElement) -> CGRect = {
        AXHelper.frame(of: $0)
    }

    /// The blocking AX title read, called OFF the main actor.
    /// `nil` is a copy that FAILED — a dead element — and never
    /// an empty title, which is a real answer a window can give.
    var titleReader: @Sendable (AXUIElement) -> String? = {
        AXHelper.attribute($0, kAXTitleAttribute, as: String.self)
    }

    /// Hops completion back to main actor (`EventLoop.onEvent`).
    var deliver:
        @Sendable (@escaping @MainActor @Sendable () -> Void)
            -> Void = { DispatchQueue.main.async(execute: $0) }

    /// Test seam for synchronous dispatch.
    var dispatchOverride:
        (
            @MainActor (pid_t, @escaping @Sendable () -> Void)
                -> Void
        )?

    private var queues: [QueueKey: DispatchQueue] = [:]
    private var inFlight: [Key: Pending] = [:]
    private var queued: [Key: Pending] = [:]

    /// Requests a coalesced frame read for a window notification
    /// (`rekeyCandidates`).
    func request(
        _ kind: Kind,
        window: WindowID,
        element: AXUIElement,
        pid: pid_t,
        onFrame: @escaping @MainActor (CGRect) -> Void
    ) {
        let reader = reader
        nonisolated(unsafe) let element = element
        enqueue(.frame(window, kind), pid: pid) {
            .frame(reader(element))
        } onReading: {
            if case .frame(let frame) = $0 { onFrame(frame) }
        }
    }

    /// Requests the liveness frame behind a focus report
    /// (#1088): one in flight per app, the newest window winning.
    func requestFocus(
        element: AXUIElement,
        pid: pid_t,
        onFrame: @escaping @MainActor (CGRect) -> Void
    ) {
        let reader = reader
        nonisolated(unsafe) let element = element
        enqueue(.focus(pid), pid: pid) {
            .frame(reader(element))
        } onReading: {
            if case .frame(let frame) = $0 { onFrame(frame) }
        }
    }

    /// Requests a coalesced title read for a title notification
    /// (#1088). A storm coalesces newest-wins like a frame storm,
    /// so the bars see the last title and at most two reads.
    func requestTitle(
        window: WindowID,
        element: AXUIElement,
        pid: pid_t,
        onTitle: @escaping @MainActor (String?) -> Void
    ) {
        let titleReader = titleReader
        nonisolated(unsafe) let element = element
        enqueue(.title(window), pid: pid) {
            .title(titleReader(element))
        } onReading: {
            if case .title(let title) = $0 { onTitle(title) }
        }
    }

    /// Requests an app's window list for an event-driven
    /// reconcile (#1930). `read` is the caller's blocking list
    /// read, run OFF the main actor; every waiter is answered.
    func requestWindows(
        pid: pid_t,
        read: @escaping @Sendable () -> [AXUIElement],
        onList: @escaping @MainActor ([AXUIElement]) -> Void
    ) {
        enqueue(.windowList(pid), pid: pid) {
            .windowList(read())
        } onReading: {
            if case .windowList(let list) = $0 { onList(list) }
        }
    }

    private func enqueue(
        _ key: Key,
        pid: pid_t,
        read: @escaping @Sendable () -> Reading,
        onReading: @escaping @MainActor (Reading) -> Void
    ) {
        var pending = Pending(
            pid: pid,
            read: read,
            onReading: onReading
        )
        if inFlight[key] != nil {
            if case .windowList = key,
                let waiting = queued[key]?.onReading
            {
                pending = Pending(pid: pid, read: read) {
                    waiting($0)
                    onReading($0)
                }
            }
            queued[key] = pending
            return
        }
        inFlight[key] = pending
        self.read(key, pending)
    }

    private func read(_ key: Key, _ pending: Pending) {
        let work = pending.read
        let deliver = deliver
        dispatch(pending.pid, lane: key.lane) { [weak self] in
            let reading = work()
            deliver {
                self?.complete(key, reading)
            }
        }
    }

    private func complete(_ key: Key, _ reading: Reading) {
        guard let pending = inFlight[key] else { return }
        pending.onReading(reading)
        if let next = queued.removeValue(forKey: key) {
            inFlight[key] = next
            read(key, next)
        } else {
            inFlight[key] = nil
        }
    }

    private func dispatch(
        _ pid: pid_t,
        lane: Lane,
        _ work: @escaping @Sendable () -> Void
    ) {
        if let dispatchOverride {
            dispatchOverride(pid, work)
            return
        }
        queue(for: pid, lane: lane).async(execute: work)
    }

    /// Returns the per-PID, per-lane serial queue — or the MAIN
    /// queue for the own process: an AX read against ourselves
    /// from a background queue deadlocks against the main actor
    /// answering it (`FrameApplier`).
    private func queue(for pid: pid_t, lane: Lane) -> DispatchQueue {
        if pid == getpid() {
            return DispatchQueue.main
        }
        let key = QueueKey(pid: pid, lane: lane)
        if let existing = queues[key] {
            return existing
        }
        let queue = DispatchQueue(
            label: "org.kiwidesk.axreads.\(lane).\(pid)",
            qos: .userInteractive
        )
        queues[key] = queue
        return queue
    }
}
