import AppKit
import Foundation

/// Hold-to-glide for keyboard resize (#1056, retimed by #1082):
/// a held resize chord keeps applying — the press's own full
/// step, then, after the system's initial delay, a GLIDE that
/// moves a fraction of that step every display frame. A Carbon
/// hot key delivers exactly one press and one release per
/// physical hold and never auto-repeats, so both halves are ours
/// to drive.
///
/// Eligibility is decided by what the press FIRE actually did:
/// exactly one command executed, it was in `glidableCommands`,
/// and it succeeded — a binding's body is opaque Lua, so the
/// tally is the one honest signal. The #933/#1055 size-limit
/// cues end a run through `noteRefusal()`, so a held resize
/// parked on a limit cues ONCE and stops. Why those are the
/// rules — and why `resize` alone glides — is argued in
/// `docs/design-decisions.md` ▸ "A held resize chord glides";
/// widen `glidableCommands` only with a ruling of that shape.
///
/// **The glide re-issues the COMMAND, never the binding** (owner
/// ruling, 2026-08-29). The press's `resize` arguments are
/// captured from the tally and re-issued with a scaled delta, so
/// the Lua body runs once, on the press. Re-running an opaque
/// body sixty to a hundred and twenty times a second would
/// repeat whatever else it does — and the single-command tally
/// already refuses to arm on such a body, so this is what makes
/// the arming rule and the run agree rather than a new licence.
/// Re-issuing through `KiwiCore.execute` keeps the capped
/// writers, the refusal cues and the command contract exactly as
/// a keypress has them. `HoldGlide+Ramp.swift` owns the ramp
/// and why speed is counted in steps per second.
///
/// Pure state machine over injected seams — the frame clock, the
/// initial delay, the scheduler and the apply are all closures —
/// so the ladder is unit-testable with no timers and no
/// `CADisplayLink` (`HoldGlideTests`).
@MainActor
final class HoldGlide {
    /// The verbs a held chord may GLIDE. `resize` alone by
    /// ruling; see the type doc before widening. Members must
    /// name real commands — `HoldGlideEligibilitySeamTests` holds the set
    /// against the API census so a §5 verb rename reds here.
    static let glidableCommands: Set<String> = ["resize"]

    /// A glide that outlives this much accumulated FRAME time is
    /// force-ended (`onOverrun`). The stop signal is one Carbon
    /// release event, and a lost one (a Mission Control switch
    /// mid-hold, a swallowed key-up) would otherwise glide for
    /// the rest of the session — the #611 force-settle shape, one
    /// subsystem over. No deliberate resize hold approaches the
    /// bound: at the ramp's top speed it is many screens of
    /// travel.
    static let maxRunSeconds: TimeInterval = 30

    /// One glide step: the press's captured command NAME, its
    /// arguments, and the factor to scale its delta by. The name
    /// travels because `glidableCommands` is the declared
    /// owner of what may glide and the rule file contemplates
    /// widening it — a wiring that hardcodes `"resize"` would
    /// then re-issue `resize` for a press that ran a different
    /// verb, with every suite green (architect review,
    /// 2026-08-29).
    ///
    /// Returns whether the command succeeded — a failure ends the
    /// glide, so a resize that starts failing (a mode change, a
    /// focus loss) stops rather than hammering the dispatcher
    /// every frame. Inert by default and wired live in
    /// `KiwiCore+HoldGlide`.
    var applyGlideStep: @MainActor (String, [JSONValue], Double) -> Bool = {
        _,
        _,
        _ in false
    }

    /// Starts the frame clock, returning its stop. Inert by
    /// default and wired live in `KiwiCore+HoldGlide`: the live
    /// object is a `CADisplayLink` on a real screen, so a live
    /// default would build one in every suite that arms a hold —
    /// the inverted-seam shape tests.md rules, which owes a guard
    /// from BOTH sides (`HoldGlideSeamTests`), so deleting the
    /// wiring reds exactly as loudly as duplicating it.
    var startFrames:
        @MainActor (@escaping @MainActor (TimeInterval) -> Void)
            -> () -> Void = { _ in {} }

    /// A run hit `maxRunSeconds` and was force-ended — wired to
    /// the manager's log seam so the rescue is visible, never
    /// silent (the #611 reporting rule).
    var onOverrun: @MainActor () -> Void = {}

    /// A glide that was RUNNING has ended, however it ended
    /// (release, refusal, failing step, teardown, overrun). Fires
    /// once per glide and never for a hold that never began
    /// gliding. It exists so work a glide frame stands down can
    /// be paid exactly once at the end — the #674 z-order arm is
    /// the first taker (`KiwiCore+HoldGlide`).
    var onGlideEnd: @MainActor () -> Void = {}

    /// Schedules `work` after `delay`; returns a cancel. This
    /// drives the ONE pre-glide wait and never the glide itself,
    /// which rides the frame clock. The production wiring is
    /// `DispatchQueue.main.asyncAfter`; tests substitute a
    /// captured slot they fire by hand.
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

    /// The system's own key-repeat delay, read once per run at
    /// the arming press: a tap moves exactly one step, and only a
    /// hold past this glides. A Settings change applies to the
    /// next hold, so the wait cannot shift mid-run.
    var initialDelay: @MainActor () -> TimeInterval = {
        NSEvent.keyRepeatDelay
    }

    /// Whether the registrar can deliver releases at all
    /// (`HotkeyReleaseReporting`). False forbids arming — a glide
    /// with no stop channel would never end.
    var releaseCapable = false

    /// One fire's tally, so a nested fire (a Lua body that pumps
    /// a run loop and delivers a second press — the case
    /// `KeybindingManager.fire`'s `wasFiring` exists for) can
    /// save the outer fire's counts and hand them back.
    struct TallySnapshot {
        let commands: Int
        let glidableSucceeded: Bool
        let refused: Bool
        let command: String
        let args: [JSONValue]
    }

    private var commandsInFire = 0
    private var glidableSucceeded = false
    private var refused = false
    /// The repeatable command the press ran, and the arguments
    /// it ran with. The glide re-issues this verb and scales its
    /// delta rather than inventing either
    /// (`HoldGlide+Ramp.swift`).
    private var fireCommand = ""
    private var fireArgs: [JSONValue] = []

    /// The registration id currently held.
    private(set) var heldID: UInt32?

    /// True from the moment the frame clock starts until the run
    /// ends — the hold's LIFETIME. Its one reader is the refusal
    /// gate, which is a lifetime question: a size-limit cue
    /// raised anywhere in the hold ends it, and
    /// `KeybindingManager.isFiring` is false outside the press
    /// fire. Anything asking "does THIS WRITE belong to the
    /// glide?" takes `isApplyingGlideStep` below instead — that
    /// property's doc argues why a lifetime bit answers the
    /// per-write question wrongly, and fails open.
    // `private(set)` would not let `HoldGlide+Run` set it —
    // Swift access control is file-scoped — so the setter is
    // internal and the type's own files are its only writers.
    var isGliding = false

    /// True for the duration of ONE glide frame's write, set
    /// around the apply in `HoldGlide+Run` and cleared by
    /// `defer` on every exit.
    ///
    /// Separate from `isGliding` deliberately (code review,
    /// 2026-08-29). A geometry path asking "does THIS WRITE
    /// belong to the glide?" must not read the hold's lifetime:
    /// that answers wrongly in both directions — an unrelated
    /// Lua, CLI or IPC `resize` arriving during a hold would
    /// silently lose its animation, and a hold whose frame clock
    /// dies (display sleep or disconnect mid-hold) would leave
    /// the bit stuck true for the session, making every later
    /// resize instant. This one cannot outlive the write it
    /// describes, and it is owned by the state machine rather
    /// than by the wiring so a re-wiring cannot forget it.
    ///
    /// Read through `KeybindingManager.isApplyingGlideStep`, the
    /// `keys.isFiring` precedent one screen up in
    /// `KiwiCore+Resize`. Who may read it is pinned by count in
    /// `HoldGlideSeamTests`, since "there is one reader" is
    /// otherwise the state claim #614 bans.
    var isApplyingGlideStep = false

    // Internal, not private: the run machinery lives in
    // `HoldGlide+Run.swift`, split at the file ceiling, and
    // Swift `private` does not cross files (the
    // `SizeBoundLearner+Invalidation` precedent).
    var cancelPending: (() -> Void)?
    var stopFrames: (() -> Void)?
    var glideArgs: [JSONValue] = []
    var glideCommand = ""
    /// Cancels the wall-clock backstop in `HoldGlide+Run`.
    var cancelBackstop: (() -> Void)?
    /// Frame time the glide has accumulated: its ramp clock AND
    /// its age, both simulated from the frames actually
    /// delivered — never wall clock (the #611 idiom), so a
    /// starved main queue cannot age a glide it never ticked, and
    /// the ramp cannot jump a stall's worth of speed.
    var glideElapsed: TimeInterval = 0

    // MARK: - Fed by KiwiCore during a fire

    /// Every `execute` inside a hotkey fire reports here; the
    /// press-fire's tally decides eligibility and carries the
    /// arguments the glide re-issues.
    func noteCommand(
        _ name: String,
        args: [JSONValue],
        succeeded: Bool
    ) {
        commandsInFire += 1
        if Self.glidableCommands.contains(name), succeeded {
            glidableSucceeded = true
            fireCommand = name
            fireArgs = args
        }
    }

    /// A size-limit refusal cue fired (#933/#1055): the run stops
    /// so the pill flashes once per hold, and the press that hit
    /// the wall arms nothing.
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
            glidableSucceeded: glidableSucceeded,
            refused: refused,
            command: fireCommand,
            args: fireArgs
        )
        commandsInFire = 0
        glidableSucceeded = false
        refused = false
        fireCommand = ""
        fireArgs = []
        return saved
    }

    func restoreTally(_ saved: TallySnapshot) {
        commandsInFire = saved.commands
        glidableSucceeded = saved.glidableSucceeded
        refused = saved.refused
        fireCommand = saved.command
        fireArgs = saved.args
    }

    /// Closes the fire `beginFire` opened and lets the ladder act
    /// on its tally. Only a physical key-down reaches here — the
    /// glide re-issues the command itself and never opens a fire,
    /// so there is no tick-fire case left to judge.
    func endFire(id: UInt32) {
        let eligible =
            releaseCapable
            && commandsInFire == 1
            && glidableSucceeded
            && !refused
        // A new press always ends any previous run — one active
        // hold at a time, latest wins — and does so before the
        // eligibility verdict, unconditionally.
        let command = fireCommand
        let args = fireArgs
        cancelRun()
        guard eligible else { return }
        heldID = id
        glideCommand = command
        glideArgs = args
        // Each press restarts the ramp, deliberately: repeated
        // short holds must never accumulate speed. A ramp that
        // carried across quick re-holds makes the third nudge in
        // a row lurch, which is the classic defect in this family
        // — so this is not a warm-start waiting to be optimised
        // in (designer round, 2026-08-29).
        glideElapsed = 0
        cancelPending = schedule(initialDelay()) { [weak self] in
            self?.cancelPending = nil
            self?.beginGlide()
        }
    }

    /// The physical release for `id` — from the registrar's
    /// release channel. A stale id (a run already replaced or
    /// cancelled) is ignored.
    func released(id: UInt32) {
        guard heldID == id else { return }
        cancelRun()
    }

    /// Any registration teardown (layer switch, suspend, reset):
    /// the ids are gone, so the run is too — an unregistered hot
    /// key delivers no release to stop on.
    func cancelRun() {
        cancelPending?()
        cancelPending = nil
        cancelBackstop?()
        cancelBackstop = nil
        stopFrames?()
        stopFrames = nil
        let wasGliding = isGliding
        isGliding = false
        heldID = nil
        glideArgs = []
        glideCommand = ""
        // Last, and only for a glide that actually ran: the
        // consumer re-enters the command layer, so every field
        // above must already read as ended.
        if wasGliding { onGlideEnd() }
    }
}
