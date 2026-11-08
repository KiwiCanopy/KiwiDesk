import AppKit
import os

/// The `.sequences` consumer's tap-thread state (#1871): the router
/// and the decisions the main actor has yet to take.
struct SequenceTapState: Sendable {
    var router = KeySequenceRouter()
    var waiting: [KeySequenceDecision] = []
    /// The main actor asked for a close; read at the next event.
    var closeRequested = false

    /// Applies a main-actor close, if one is waiting.
    mutating func takeClose() {
        guard closeRequested else { return }
        closeRequested = false
        router.close()
    }

    /// Records a decision the main actor must take; false for one
    /// it need not hear.
    mutating func record(_ outcome: KeySequenceRouter.Outcome) -> Bool {
        guard outcome != .pass, outcome != .repeated else { return false }
        waiting.append(
            KeySequenceDecision(outcome: outcome, progress: router.progress)
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

    /// Whether `event` is the consumer's to swallow.
    func sequenceEvent(_ type: CGEventType, _ event: CGEvent) -> Bool {
        let code = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        let held = HotkeyModifiers.held(by: event.flags)
        let isRepeat =
            event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let (swallow, heard) = sequenceState.withLock {
            state -> (Bool, Bool) in
            state.takeClose()
            switch type {
            case .keyDown:
                let outcome = state.router.press(
                    keyCode: code,
                    held: held,
                    isRepeat: isRepeat
                )
                return (outcome != .pass, state.record(outcome))
            case .leftMouseDown, .rightMouseDown, .otherMouseDown:
                guard state.router.isOpen else { return (false, false) }
                state.router.close()
                return (false, state.record(.closed))
            default:
                return (false, false)
            }
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
            return $0.record($0.router.openLeader(Int(id - Self.leaderBase)))
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
