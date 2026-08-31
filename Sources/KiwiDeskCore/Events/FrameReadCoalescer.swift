import ApplicationServices
import CoreGraphics
import Foundation

/// Coalesces asynchronous AX frame reads off the main actor
/// (#618). Per-PID serial reads keep one slow app from blocking
/// the main thread (`FrameApplier`). Two residuals are accepted:
/// an event can deliver after its window's destroy, and
/// `trackedFrames` can lag by one read — draining pending reads
/// before a reconcile would re-block the main actor, the cost
/// this type exists to remove.
@MainActor
final class FrameReadCoalescer {
    enum Kind: Hashable, Sendable {
        case moved
        case resized
        /// Post-settle frame probe (#677).
        case settleProbe
    }

    private struct Key: Hashable, Sendable {
        let window: WindowID
        let kind: Kind
    }

    private struct Pending {
        let element: AXUIElement
        let pid: pid_t
        let onFrame: @MainActor (CGRect) -> Void
    }

    /// The blocking AX read, called OFF the main actor.
    var reader: @Sendable (AXUIElement) -> CGRect = {
        AXHelper.frame(of: $0)
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

    private var queues: [pid_t: DispatchQueue] = [:]
    private var inFlight: [Key: Pending] = [:]
    private var queued: [Key: Pending] = [:]

    /// Requests coalesced frame read for window notification
    /// (`rekeyCandidates`).
    func request(
        _ kind: Kind,
        window: WindowID,
        element: AXUIElement,
        pid: pid_t,
        onFrame: @escaping @MainActor (CGRect) -> Void
    ) {
        let key = Key(window: window, kind: kind)
        let pending = Pending(
            element: element,
            pid: pid,
            onFrame: onFrame
        )
        if inFlight[key] != nil {
            queued[key] = pending
            return
        }
        inFlight[key] = pending
        read(key, pending)
    }

    private func read(_ key: Key, _ pending: Pending) {
        nonisolated(unsafe) let element = pending.element
        let reader = reader
        let deliver = deliver
        dispatch(pending.pid) { [weak self] in
            let frame = reader(element)
            deliver {
                self?.complete(key, frame: frame)
            }
        }
    }

    private func complete(_ key: Key, frame: CGRect) {
        guard let pending = inFlight[key] else { return }
        pending.onFrame(frame)
        if let next = queued.removeValue(forKey: key) {
            inFlight[key] = next
            read(key, next)
        } else {
            inFlight[key] = nil
        }
    }

    private func dispatch(
        _ pid: pid_t,
        _ work: @escaping @Sendable () -> Void
    ) {
        if let dispatchOverride {
            dispatchOverride(pid, work)
            return
        }
        queue(for: pid).async(execute: work)
    }

    /// Returns per-PID serial queue — or the MAIN queue for the
    /// own process: an AX read against ourselves from a background
    /// queue deadlocks against the main actor answering it
    /// (`FrameApplier`).
    private func queue(for pid: pid_t) -> DispatchQueue {
        if pid == getpid() {
            return DispatchQueue.main
        }
        if let existing = queues[pid] {
            return existing
        }
        let queue = DispatchQueue(
            label: "org.kiwidesk.framereads.\(pid)",
            qos: .userInteractive
        )
        queues[pid] = queue
        return queue
    }
}
