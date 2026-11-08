import AppKit
import os

/// The `.sequences` consumer's tap-thread state (#1871): the router
/// and the decisions the main actor has yet to take.
struct SequenceTapState: Sendable {
    var router = KeySequenceRouter()
    var waiting: [KeySequenceDecision] = []
    /// The main actor asked for a close; read at the next event.
    var closeRequested = false
    var generation: UInt64 = 0

    /// New rows: the open sequence closes, and nothing decided over
    /// the old rows is left to drain.
    mutating func reset(_ rows: KeyboardTapRows) {
        router.setSequences(rows.sequences)
        generation = rows.sequenceGeneration
        waiting = []
        closeRequested = false
    }

    /// Applies a main-actor close, if one is waiting, and says so,
    /// so a decision queued before it is followed by the close.
    mutating func takeClose() {
        guard closeRequested else { return }
        closeRequested = false
        guard router.isOpen else { return }
        router.close()
        _ = record(.closed)
    }

    /// Records a decision the main actor must take; false for one
    /// it need not hear.
    mutating func record(_ outcome: KeySequenceRouter.Outcome) -> Bool {
        guard outcome != .pass, outcome != .repeated else { return false }
        waiting.append(
            KeySequenceDecision(
                outcome: outcome,
                progress: router.progress,
                generation: generation
            )
        )
        return true
    }
}

/// The `.sequences` consumer (#1871): the open-or-closed state is
/// decided here, on the tap's thread, from the key-downs the tap
/// itself sees, so no key after a leader reaches the front app. The
/// main actor hears each decision through `fire(sequenceFireID)`.
extension KeyboardTap {
    /// The id that asks the main actor to drain the decisions.
    static let sequenceFireID: UInt32 = .max
    /// Tap-leader rows ride `.modifierTaps` under ids from here up,
    /// the sequence's index added.
    static let leaderBase: UInt32 = 0xF000_0000

    static func leaderID(_ index: Int) -> UInt32 {
        leaderBase + UInt32(index)
    }

    /// Whether `event` is the consumer's to swallow: a leader, and
    /// every key-down while a sequence is open. A mouse-down closes
    /// an open one and passes, the one door a click closes by.
    func sequenceEvent(_ type: CGEventType, _ event: CGEvent) -> Bool {
        let code = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        let held = HotkeyModifiers.held(by: event.flags)
        let isRepeat =
            event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let (swallow, heard) = sequenceState.withLock {
            state -> (Bool, Bool) in
            state.takeClose()
            var swallow = false
            switch type {
            case .keyDown:
                let outcome = state.router.press(
                    keyCode: code,
                    held: held,
                    isRepeat: isRepeat
                )
                swallow = outcome != .pass
                _ = state.record(outcome)
            case .leftMouseDown, .rightMouseDown, .otherMouseDown:
                if state.router.isOpen {
                    state.router.close()
                    _ = state.record(.closed)
                }
            default:
                break
            }
            return (swallow, !state.waiting.isEmpty)
        }
        if heard { fire(Self.sequenceFireID) }
        return swallow
    }

    /// `.modifierTaps` fires `id`, or opens the sequence a tap leader
    /// names, on the thread that decided it.
    func fireOrOpen(_ id: UInt32) {
        guard id >= Self.leaderBase, id != Self.sequenceFireID else {
            fire(id)
            return
        }
        let heard = sequenceState.withLock {
            $0.takeClose()
            _ = $0.record($0.router.openLeader(Int(id - Self.leaderBase)))
            return !$0.waiting.isEmpty
        }
        if heard { fire(Self.sequenceFireID) }
    }

    #if DEBUG
        /// Tests only: a tap that never installs, whose consumers a
        /// suite drives with fabricated events. Production must not
        /// read this.
        static func unstarted(
            consumers: Set<KeyboardTapConsumer>,
            fire: @escaping Fire
        ) -> KeyboardTap {
            KeyboardTap(consumers: consumers, fire: fire, report: { _ in })
        }
    #endif

    /// Closes an open sequence after the tap was off.
    func closeSequenceAfterGap() {
        let heard = sequenceState.withLock { state -> Bool in
            guard state.router.isOpen else { return false }
            state.router.close()
            return state.record(.closed)
        }
        if heard { fire(Self.sequenceFireID) }
    }

    func drainSequenceDecisions() -> [KeySequenceDecision] {
        sequenceState.withLock { state in
            defer { state.waiting = [] }
            return state.waiting
        }
    }

    func requestSequenceClose() {
        sequenceState.withLock { $0.closeRequested = true }
    }
}
