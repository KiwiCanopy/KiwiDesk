import AppKit
import Foundation

/// Hold-to-repeat for keyboard resize (#1056): a held resize
/// chord keeps applying — an initial delay, then a repeat
/// interval, the ordinary key-repeat shape — because a Carbon
/// hot key delivers exactly one press and one release per
/// physical hold and never auto-repeats on its own.
///
/// Eligibility is decided by what the press FIRE actually did:
/// exactly one command executed, it was in `repeatableCommands`,
/// and it succeeded — a binding's body is opaque Lua, so the
/// tally is the one honest signal. The #933/#1055 size-limit
/// cues end a run through `noteRefusal()`, so a held resize
/// parked on a limit cues ONCE and stops ticking. Why those are
/// the rules — and why `resize` alone repeats — is argued in
/// `docs/design-decisions.md` ▸ "A held resize chord repeats";
/// widen `repeatableCommands` only with a ruling of that shape.
///
/// **Timing is the system's, then it accelerates.** The initial
/// delay and the interval default to the user's own key-repeat
/// settings (`NSEvent.keyRepeatDelay` / `.keyRepeatInterval`),
/// both read once at the arming press — a Settings change
/// applies to the next hold, and the ramp's base cannot shift
/// mid-run. A long hold speeds up; the shape and its feel
/// constants live in `HoldRepeat+Acceleration.swift`.
///
/// Pure state machine over injected seams — the scheduler, the
/// timings and the re-fire are all closures — so the ladder is
/// unit-testable with no timers (`HoldRepeatTests`).
@MainActor
final class HoldRepeat {
    /// The verbs a held chord may repeat. `resize` alone by
    /// ruling; see the type doc before widening. Members must
    /// name real commands — `HoldRepeatSeamTests` holds the set
    /// against the API census so a §5 verb rename reds here.
    static let repeatableCommands: Set<String> = ["resize"]

    /// A run that outlives this much accumulated scheduled
    /// delay is force-ended (`onOverrun`). The stop signal is
    /// one Carbon release event, and a lost one (a Mission
    /// Control switch mid-hold, a swallowed key-up) would
    /// otherwise re-fire `resize` at up to `maxSpeedup`× the
    /// system rate for the rest of the session — the #611
    /// force-settle shape, one subsystem over. No deliberate
    /// resize hold approaches this bound: at the default rate
    /// it is several screens of travel.
    static let maxRunSeconds: TimeInterval = 30

    /// Re-fires the held binding — wired by
    /// `KeybindingManager`, keyed by registration id.
    var fire: @MainActor (UInt32) -> Void = { _ in }

    /// A run hit `maxRunSeconds` and was force-ended — wired to
    /// the manager's log seam so the rescue is visible, never
    /// silent (the #611 reporting rule).
    var onOverrun: @MainActor () -> Void = {}

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

    /// The system key-repeat shape, read once per run at the
    /// arming press.
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

    /// One fire's tally, so a nested fire (a Lua body that
    /// pumps a run loop and delivers a second press — the case
    /// `KeybindingManager.fire`'s `wasFiring` exists for) can
    /// save the outer fire's counts and hand them back.
    struct TallySnapshot {
        let commands: Int
        let repeatableSucceeded: Bool
        let refused: Bool
    }

    private var commandsInFire = 0
    private var repeatableSucceeded = false
    private var refused = false
    /// The registration id currently held and repeating.
    private(set) var heldID: UInt32?
    private var cancelPending: (() -> Void)?
    /// Repeat ticks completed by the current run — the
    /// acceleration ramp's clock, reset by each arming press.
    private var tickCount = 0
    /// The run's interval base, read once at the arming press.
    private var runBase: TimeInterval = 0
    /// Scheduled delay the run has accumulated — simulated age,
    /// never wall clock (the #611 idiom): what was scheduled is
    /// what bounds the run, so a starved main queue cannot age
    /// a run it never ticked.
    private var runAge: TimeInterval = 0

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

    /// Opens one binding fire's tally, returning the previous
    /// tally for the caller to `restoreTally` afterwards — a
    /// no-op pair except in the nested-fire case the snapshot's
    /// doc names.
    func beginFire() -> TallySnapshot {
        let saved = TallySnapshot(
            commands: commandsInFire,
            repeatableSucceeded: repeatableSucceeded,
            refused: refused
        )
        commandsInFire = 0
        repeatableSucceeded = false
        refused = false
        return saved
    }

    func restoreTally(_ saved: TallySnapshot) {
        commandsInFire = saved.commands
        repeatableSucceeded = saved.repeatableSucceeded
        refused = saved.refused
    }

    /// Closes the fire `beginFire` opened and lets the ladder
    /// act on its tally. `press` is true for the physical
    /// key-down fire, false for a repeat tick — only a press
    /// may ARM a run (a tick extends or ends the one it belongs
    /// to).
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
            tickCount = 0
            runBase = interval()
            runAge = 0
            scheduleTick(after: initialDelay())
        } else {
            guard heldID == id else { return }
            guard eligible else {
                cancelRun()
                return
            }
            guard runAge < Self.maxRunSeconds else {
                cancelRun()
                onOverrun()
                return
            }
            tickCount += 1
            scheduleTick(
                after: Self.acceleratedInterval(
                    base: runBase,
                    tick: tickCount
                )
            )
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
        runAge += delay
        cancelPending = schedule(delay) { [weak self] in
            guard let self, let id = self.heldID else { return }
            self.cancelPending = nil
            self.fire(id)
        }
    }
}
