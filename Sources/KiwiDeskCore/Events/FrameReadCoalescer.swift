import ApplicationServices
import CoreGraphics
import Foundation

/// Takes the per-notification AX frame read off the main actor
/// (#618). A `windowMoved`/`windowResized` notification carries
/// no geometry, so the event loop must read the frame back —
/// blocking IPC into the very app that is busiest at exactly
/// that moment (a live mouse resize saturates its main thread).
/// Read on the main actor, one stalled answer parks KiwiDesk
/// for the app's whole busy stretch (~150–210 ms measured), and
/// the WindowServer event queue that drives the focus ring
/// starves behind it — the freeze-then-teleport of #618.
///
/// So reads run on one serial queue per app (the `FrameApplier`
/// write-side precedent: a slow app delays only its own
/// events), with newest-wins coalescing per (window, kind): at
/// most one read is in flight per key, arrivals during a flight
/// leave a dirty mark, and completion re-reads once — so the
/// FINAL frame always lands even when a storm's intermediate
/// notifications were skipped. The read returns the CURRENT
/// frame, which is why skipping intermediates loses nothing the
/// old path kept: it read the same live value, just later and
/// on the wrong thread.
///
/// Delivery hops back to the main actor, so every consumer
/// downstream of `EventLoop.onEvent` is unchanged. Accepted: an
/// event can now deliver after its window's destroy — already
/// possible via run-loop queuing, and every consumer no-ops on
/// an unknown id.
@MainActor
final class FrameReadCoalescer {
    enum Kind: Hashable, Sendable {
        case moved
        case resized
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
    /// Injectable so tests substitute a pure value.
    var reader: @Sendable (AXUIElement) -> CGRect = {
        AXHelper.frame(of: $0)
    }

    /// Hops a completion back to the main actor. The SkyLight
    /// event queue's scheduler shape; tests substitute an
    /// immediate executor for determinism.
    var deliver:
        @Sendable (@escaping @MainActor @Sendable () -> Void)
            -> Void = { DispatchQueue.main.async(execute: $0) }

    /// Test seam replacing the per-pid serial queues: run the
    /// read work synchronously or capture it for pumping.
    var dispatchOverride:
        (
            @MainActor (pid_t, @escaping @Sendable () -> Void)
                -> Void
        )?

    private var queues: [pid_t: DispatchQueue] = [:]
    private var inFlight: [Key: Pending] = [:]
    private var queued: [Key: Pending] = [:]

    /// Requests a frame read for one notification. `onFrame`
    /// runs on the main actor with the frame the app answered;
    /// during a storm, requests that arrive while a read is in
    /// flight coalesce — their completions are superseded by
    /// the newest request's, which is delivered with a fresh
    /// read once the in-flight one returns.
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
        // AXUIElement is thread-safe; the annotation mirrors
        // FrameApplier's write side.
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
            // Dirty: notifications arrived mid-flight, so the
            // frame moved on — read again so the final one
            // lands. Stays in flight, keeping one read per key.
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

    /// One serial queue per app, kept for the app's lifetime —
    /// the `FrameApplier` argument: a stalled app must delay
    /// only its own windows' reads, and one idle queue per app
    /// is cheaper than two queues racing AX calls.
    private func queue(for pid: pid_t) -> DispatchQueue {
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
