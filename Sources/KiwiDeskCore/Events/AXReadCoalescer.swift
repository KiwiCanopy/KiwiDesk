import ApplicationServices
import CoreGraphics
import Foundation

/// Coalesces asynchronous AX reads off the main actor (#618):
/// the frame behind a move/resize notification, the liveness
/// frame behind a focus report and the title behind a title
/// notification (#1088). Per-PID serial reads keep one slow app
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
        /// A focus report's liveness read (#1088): the frame,
        /// whose `.zero` names a dead element.
        case focused
    }

    private enum Key: Hashable, Sendable {
        case frame(WindowID, Kind)
        case title(WindowID)
    }

    /// What one read answered — the key decides which.
    private enum Reading: Sendable {
        case frame(CGRect)
        case title(String?)
    }

    private struct Pending {
        let element: AXUIElement
        let pid: pid_t
        let onReading: @MainActor (Reading) -> Void
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

    private var queues: [pid_t: DispatchQueue] = [:]
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
        enqueue(.frame(window, kind), element: element, pid: pid) {
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
        enqueue(.title(window), element: element, pid: pid) {
            if case .title(let title) = $0 { onTitle(title) }
        }
    }

    private func enqueue(
        _ key: Key,
        element: AXUIElement,
        pid: pid_t,
        onReading: @escaping @MainActor (Reading) -> Void
    ) {
        let pending = Pending(
            element: element,
            pid: pid,
            onReading: onReading
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
        let titleReader = titleReader
        let deliver = deliver
        dispatch(pending.pid) { [weak self] in
            let reading: Reading
            switch key {
            case .frame:
                reading = .frame(reader(element))
            case .title:
                reading = .title(titleReader(element))
            }
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
            label: "org.kiwidesk.axreads.\(pid)",
            qos: .userInteractive
        )
        queues[pid] = queue
        return queue
    }
}
