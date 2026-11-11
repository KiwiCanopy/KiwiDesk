import AppKit
import os

/// The `.sequences` consumer's tap-thread state (#1871): the router
/// and the decisions the main actor has yet to take.
struct SequenceTapState: Sendable {
    var router = KeySequenceRouter()
    var waiting: [KeySequenceDecision] = []
    /// The epoch a main close asked for; taken at the next event.
    var closeRequested: UInt64?
    var generation: UInt64 = 0

    /// New rows: the open sequence closes, and nothing decided over
    /// the old rows is left to drain.
    mutating func reset(_ rows: KeyboardTapRows) {
        router.setSequences(rows.sequences, passing: rows.sequencePassing)
        router.scrollKeys = rows.sequenceScrollKeys
        generation = rows.sequenceGeneration
        waiting = []
        closeRequested = nil
    }

    /// Applies a main-actor close, if one is waiting: the sequence
    /// closes, and later decisions carry its epoch. The main actor
    /// has already told the panel, and drops the older ones.
    mutating func takeClose() {
        guard let epoch = closeRequested else { return }
        closeRequested = nil
        router.close()
        generation = epoch
    }

    /// Records a decision the main actor must take; false for one
    /// it need not hear.
    mutating func record(_ outcome: KeySequenceRouter.Outcome) -> Bool {
        switch outcome {
        case .pass, .repeated, .passed(closing: false): return false
        default: break
        }
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
    /// every key-down while a sequence is open save a macOS shortcut
    /// it lets through (#3173). A mouse-down closes an open one and
    /// passes, the one door a click closes by.
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
                swallow = outcome.swallows
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

    func requestSequenceClose(generation: UInt64) {
        sequenceState.withLock { $0.closeRequested = generation }
    }
}
