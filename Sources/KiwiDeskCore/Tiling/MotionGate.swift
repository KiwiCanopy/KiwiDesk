import CoreGraphics
import Foundation

/// The input-quiescence gate (#804 ▸ Ruling): ambient window motion,
/// and a user call's late tail, wait for the hand to rest; motion a
/// KiwiDesk control is making right now passes, and discharges every
/// held one with it. Asked at the engine's two frame doors
/// (`applyFrame`, `setFrame`) BEFORE they stamp the placement or
/// retire an ask, so a held move records nothing until it is sent.
/// Only motion waits: state, the bars and the rings move at once.
@MainActor
final class MotionGate {
    /// One held move, latest per window.
    enum Held: Equatable {
        case frame(
            from: CGRect,
            to: CGRect,
            animated: Bool,
            isNew: Bool,
            sizing: BatchSizing
        )
        case set(CGRect, setSize: Bool)
    }

    let quiescence = InputQuiescence()
    /// The cause of the write being asked about — the applier's
    /// one reading.
    var cause: @MainActor () -> MotionCause = { .ambient }
    var clock: @MainActor () -> TimeInterval = { 0 }
    /// Re-asks after `delay`; a test drives it by hand.
    var schedule:
        @MainActor (TimeInterval, @escaping @MainActor () -> Void)
            -> Void = { delay, work in
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    MainActor.assumeIsolated(work)
                }
            }
    /// Sends one released move back through its door.
    var release: @MainActor (WindowID, Held) -> Void = { _, _ in }
    var onLog: @MainActor (String) -> Void = CoreLog.write

    private(set) var held: [WindowID: Held] = [:]
    private var heldSince: TimeInterval?
    private var armed = false
    private var releasing = false

    func isHolding(_ id: WindowID) -> Bool { held[id] != nil }

    /// Whether this write to `id` waits; true means the door sends
    /// nothing now.
    func holds(_ id: WindowID, _ move: Held) -> Bool {
        guard !releasing else { return false }
        let cause = cause()
        if case .user(_, late: false) = cause {
            held[id] = nil
            flush(why: "a user pass")
            return false
        }
        let heldFor = heldSince.map { clock() - $0 }
        if quiescence.admits(heldFor: heldFor) {
            flush(why: "the hand rests")
            return false
        }
        held[id] = merged(held[id], move)
        if heldSince == nil {
            heldSince = clock()
            onLog("motion held: \(Self.describe(cause))")
        }
        arm()
        return true
    }

    /// Forgets every held move: KiwiDesk is stopping or resting,
    /// or the saved arrangement was discarded.
    func dropAll() {
        held = [:]
        heldSince = nil
    }

    private func arm() {
        guard !armed else { return }
        armed = true
        schedule(InputQuiescence.poll) { [weak self] in
            guard let self else { return }
            self.armed = false
            guard !self.held.isEmpty else {
                self.heldSince = nil
                return
            }
            let heldFor = self.heldSince.map { self.clock() - $0 }
            if self.quiescence.admits(heldFor: heldFor) {
                self.flush(why: "the hand rests")
            } else {
                self.arm()
            }
        }
    }

    private func flush(why: String) {
        guard !held.isEmpty else {
            heldSince = nil
            return
        }
        let moves = held
        let waited = heldSince.map { clock() - $0 } ?? 0
        held = [:]
        heldSince = nil
        onLog(
            "motion released after \(Int(waited * 1000)) ms "
                + "(\(moves.count) window(s), \(why))"
        )
        releasing = true
        defer { releasing = false }
        for (id, move) in moves { release(id, move) }
    }

    /// Latest wins; a size set is never dropped, and a slide keeps
    /// the frame it starts from, since the window has not moved.
    private func merged(_ old: Held?, _ new: Held) -> Held {
        switch (old, new) {
        case (.set(_, let wasSized)?, .set(let frame, let sized)):
            return .set(frame, setSize: wasSized || sized)
        case (
            .frame(let from, _, _, _, _)?,
            .frame(_, let to, let a, let n, let s)
        ):
            return .frame(from: from, to: to, animated: a, isNew: n, sizing: s)
        default:
            return new
        }
    }

    private static func describe(_ cause: MotionCause) -> String {
        switch cause {
        case .ambient: return "ambient"
        case .user: return "user, late"
        }
    }
}

extension TilingEngine {
    /// Sends a move the gate released back through its own door.
    func releaseHeldMotion(_ id: WindowID, _ move: MotionGate.Held) {
        switch move {
        case .frame(let from, let to, let animated, let isNew, let sizing):
            applyFrame(
                id,
                from: from,
                to: to,
                animated: animated,
                isNewWindow: isNew,
                sizing: sizing
            )
        case .set(let frame, let setSize):
            setFrame(id, frame, setSize: setSize)
        }
    }
}
