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
/// exactly one command executed, it was in `repeatableCommands`,
/// and it succeeded — a binding's body is opaque Lua, so the
/// tally is the one honest signal. The #933/#1055 size-limit
/// cues end a run through `noteRefusal()`, so a held resize
/// parked on a limit cues ONCE and stops. Why those are the
/// rules — and why `resize` alone repeats — is argued in
/// `docs/design-decisions.md` ▸ "A held resize chord glides";
/// widen `repeatableCommands` only with a ruling of that shape.
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
/// a keypress has them. `HoldRepeat+Glide.swift` owns the ramp
/// and why speed is counted in steps per second.
///
/// Pure state machine over injected seams — the frame clock, the
/// initial delay, the scheduler and the apply are all closures —
/// so the ladder is unit-testable with no timers and no
/// `CADisplayLink` (`HoldRepeatTests`).
@MainActor
final class HoldRepeat {
    /// The verbs a held chord may repeat. `resize` alone by
    /// ruling; see the type doc before widening. Members must
    /// name real commands — `HoldRepeatSeamTests` holds the set
    /// against the API census so a §5 verb rename reds here.
    static let repeatableCommands: Set<String> = ["resize"]

    /// A glide that outlives this much accumulated FRAME time is
    /// force-ended (`onOverrun`). The stop signal is one Carbon
    /// release event, and a lost one (a Mission Control switch
    /// mid-hold, a swallowed key-up) would otherwise glide for
    /// the rest of the session — the #611 force-settle shape, one
    /// subsystem over. No deliberate resize hold approaches the
    /// bound: at the ramp's top speed it is many screens of
    /// travel.
    static let maxRunSeconds: TimeInterval = 30

    /// One glide step: the press's captured arguments and the
    /// factor to scale its delta by. Returns whether the command
    /// succeeded — a failure ends the glide, so a resize that
    /// starts failing (a mode change, a focus loss) stops rather
    /// than hammering the dispatcher every frame. Inert by
    /// default and wired live in `KiwiCore+HoldGlide`.
    var applyGlideStep: @MainActor ([JSONValue], Double) -> Bool = { _, _ in
        false
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
        let repeatableSucceeded: Bool
        let refused: Bool
        let args: [JSONValue]
    }

    private var commandsInFire = 0
    private var repeatableSucceeded = false
    private var refused = false
    /// The repeatable command's arguments as the press ran them.
    /// The glide scales this delta rather than inventing a
    /// distance of its own (`HoldRepeat+Glide.swift`).
    private var fireArgs: [JSONValue] = []

    /// The registration id currently held.
    private(set) var heldID: UInt32?

    /// True from the moment the frame clock starts until the run
    /// ends. Two readers, both needing "a held glide is applying
    /// right now" at a moment when `KeybindingManager.isFiring`
    /// is false: the refusal gate, and the resize paths' choice
    /// to write instantly (`KiwiCore.resizeRetileAnimated`).
    private(set) var isGliding = false

    private var cancelPending: (() -> Void)?
    private var stopFrames: (() -> Void)?
    private var glideArgs: [JSONValue] = []
    /// Frame time the glide has accumulated: its ramp clock AND
    /// its age, both simulated from the frames actually
    /// delivered — never wall clock (the #611 idiom), so a
    /// starved main queue cannot age a glide it never ticked, and
    /// the ramp cannot jump a stall's worth of speed.
    private var glideElapsed: TimeInterval = 0

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
        if Self.repeatableCommands.contains(name), succeeded {
            repeatableSucceeded = true
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
            repeatableSucceeded: repeatableSucceeded,
            refused: refused,
            args: fireArgs
        )
        commandsInFire = 0
        repeatableSucceeded = false
        refused = false
        fireArgs = []
        return saved
    }

    func restoreTally(_ saved: TallySnapshot) {
        commandsInFire = saved.commands
        repeatableSucceeded = saved.repeatableSucceeded
        refused = saved.refused
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
            && repeatableSucceeded
            && !refused
        // A new press always ends any previous run — one active
        // hold at a time, latest wins — and does so before the
        // eligibility verdict, unconditionally.
        let args = fireArgs
        cancelRun()
        guard eligible else { return }
        heldID = id
        glideArgs = args
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
        stopFrames?()
        stopFrames = nil
        isGliding = false
        heldID = nil
        glideArgs = []
    }

    private func beginGlide() {
        guard heldID != nil else { return }
        isGliding = true
        stopFrames = startFrames { [weak self] dt in
            self?.glideFrame(dt: dt)
        }
    }

    /// One display frame of glide: move the ramp's current speed
    /// for the time this frame actually took. `dt` arrives
    /// clamped by the driver, so a stalled frame costs distance
    /// rather than lurching a whole stall's worth in one step.
    private func glideFrame(dt: TimeInterval) {
        guard isGliding, heldID != nil, dt > 0 else { return }
        guard glideElapsed < Self.maxRunSeconds else {
            cancelRun()
            onOverrun()
            return
        }
        // The ramp is read BEFORE the frame is banked, so the
        // first frame moves at `glideStartSteps` rather than one
        // frame's worth into the ramp.
        let scale = Self.glideSteps(elapsed: glideElapsed) * dt
        glideElapsed += dt
        let args = glideArgs
        guard applyGlideStep(args, scale) else {
            // Already cancelled if the step cued a refusal; a
            // second cancel is idempotent.
            cancelRun()
            return
        }
    }
}
