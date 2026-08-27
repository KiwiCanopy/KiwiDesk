import AppKit
import Foundation

/// Hold-to-repeat for keyboard resize (#1056): a held resize
/// chord keeps applying — an initial delay, then a repeat
/// interval, the ordinary key-repeat shape — because a Carbon
/// hot key delivers exactly one press and one release per
/// physical hold and never auto-repeats on its own.
///
/// **What repeats is a ruling, not an inference.** A binding's
/// body is opaque Lua, so eligibility is decided by what the
/// press FIRE actually did: exactly one command executed, it
/// was in `repeatableCommands`, and it succeeded. A body that
/// runs two commands, or a verb like `focus` where overshooting
/// is worse than pressing again, never arms — widening the set
/// is a one-line change here, weighed per verb
/// (`docs/design-decisions.md` owns the resize-only ruling).
///
/// **A refusal ends the run.** The #933/#1055 size-limit cues
/// call `noteRefusal()`, so a held resize parked on a floor or
/// ceiling cues ONCE and stops ticking instead of flashing a
/// pill per repeat. The wordless viewport park keeps ticking
/// harmlessly until release — there is deliberately no signal
/// to stop on (`KiwiCore+ResizeScrollSlot`'s silence ruling).
///
/// **Timing is the system's.** The initial delay and interval
/// default to the user's own key-repeat settings
/// (`NSEvent.keyRepeatDelay` / `.keyRepeatInterval`), read per
/// run so a Settings change applies to the next hold. No
/// acceleration — a first press stays one precise step.
///
/// Pure state machine over injected seams — the scheduler, the
/// timings and the re-fire are all closures — so the ladder is
/// unit-testable with no timers (`HoldRepeatTests`).
@MainActor
final class HoldRepeat {
    /// The verbs a held chord may repeat. `resize` alone by
    /// ruling; see the type doc before widening.
    static let repeatableCommands: Set<String> = ["resize"]

    /// Re-fires the held binding — wired by
    /// `KeybindingManager`, keyed by registration id.
    var fire: @MainActor (UInt32) -> Void = { _ in }

    /// Schedules `work` after `delay`; returns a cancel. The
    /// production wiring is `DispatchQueue.main.asyncAfter`;
    /// tests substitute a captured slot they fire by hand.
    var schedule:
        @MainActor (
            TimeInterval, @escaping @MainActor () -> Void
        ) -> () -> Void = { delay, work in
            let item = DispatchWorkItem { work() }
            DispatchQueue.main.asyncAfter(
                deadline: .now() + delay,
                execute: item
            )
            return { item.cancel() }
        }

    /// The system key-repeat shape, read per run.
    var initialDelay: @MainActor () -> TimeInterval = {
        NSEvent.keyRepeatDelay
    }
    var interval: @MainActor () -> TimeInterval = {
        NSEvent.keyRepeatInterval
    }

    /// Whether the registrar can deliver releases at all
    /// (`HotkeyReleaseReporting`). False forbids arming — a
    /// repeat with no release channel would never stop.
    var releaseCapable = false

    private var commandsInFire = 0
    private var repeatableSucceeded = false
    private var refused = false
    /// The registration id currently held and repeating.
    private(set) var heldID: UInt32?
    private var cancelPending: (() -> Void)?

    // MARK: - Fed by KiwiCore during a fire

    /// Every `execute` inside a hotkey fire reports here; the
    /// press-fire's tally decides eligibility, a tick-fire's
    /// tally decides whether the run goes on.
    func noteCommand(_ name: String, succeeded: Bool) {
        commandsInFire += 1
        if Self.repeatableCommands.contains(name), succeeded {
            repeatableSucceeded = true
        }
    }

    /// A size-limit refusal cue fired (#933/#1055): the run
    /// stops so the pill flashes once per hold, and the press
    /// that hit the wall arms nothing.
    func noteRefusal() {
        refused = true
        cancelRun()
    }

    // MARK: - Driven by KeybindingManager

    /// Brackets one binding fire. `press` is true for the
    /// physical key-down fire, false for a repeat tick — only a
    /// press may ARM a run (a tick extends or ends the one it
    /// belongs to).
    func beginFire() {
        commandsInFire = 0
        repeatableSucceeded = false
        refused = false
    }

    func endFire(id: UInt32, press: Bool) {
        let eligible =
            releaseCapable
            && commandsInFire == 1
            && repeatableSucceeded
            && !refused
        if press {
            // A new press always ends any previous run — one
            // active hold at a time, latest wins.
            cancelRun()
            guard eligible else { return }
            heldID = id
            scheduleTick(after: initialDelay())
        } else {
            guard heldID == id else { return }
            guard eligible else {
                cancelRun()
                return
            }
            scheduleTick(after: interval())
        }
    }

    /// The physical release for `id` — from the registrar's
    /// release channel. A stale id (a run already replaced or
    /// cancelled) is ignored.
    func released(id: UInt32) {
        guard heldID == id else { return }
        cancelRun()
    }

    /// Any registration teardown (layer switch, suspend,
    /// reset): the ids are gone, so the run is too — an
    /// unregistered hot key delivers no release to stop on.
    func cancelRun() {
        cancelPending?()
        cancelPending = nil
        heldID = nil
    }

    private func scheduleTick(after delay: TimeInterval) {
        cancelPending?()
        cancelPending = schedule(delay) { [weak self] in
            guard let self, let id = self.heldID else { return }
            self.cancelPending = nil
            self.fire(id)
        }
    }
}
