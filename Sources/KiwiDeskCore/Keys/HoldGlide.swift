import AppKit
import Foundation

/// Hold-to-glide for keyboard resize (#1056, retimed by #1082). A held resize
/// chord glides after initial key-repeat delay. Re-issues the command (never
/// binding, owner ruling 2026-08-29) with scaled delta (`HoldGlideTests`).
/// Refusal cues stop run (#933, #1055).
@MainActor
final class HoldGlide {
    /// The verbs a held chord may glide (only `resize`). Checked in
    /// `HoldGlideEligibilitySeamTests` against the API census (#614).
    static let glidableCommands: Set<String> = ["resize"]

    /// Force-end bound if release event is lost (#611).
    static let maxRunSeconds: TimeInterval = 30

    /// One glide step: command name, args, delta factor (architect review,
    /// 2026-08-29). Returns success. Inert by default; wired in KiwiCore.
    var applyGlideStep: @MainActor (String, [JSONValue], Double) -> Bool = {
        _,
        _,
        _ in false
    }

    /// Starts the frame clock; returns stop closure (`HoldGlideSeamTests`).
    var startFrames:
        @MainActor (@escaping @MainActor (TimeInterval) -> Void)
            -> () -> Void = { _ in {} }

    /// Fired on `maxRunSeconds` overrun (#611).
    var onOverrun: @MainActor () -> Void = {}

    /// Fires once on physical press start to retire press-scoped records
    /// (#1090).
    var onFireBegan: @MainActor () -> Void = {}

    /// Fires once when a running glide ends (e.g. #674 z-order restore).
    var onGlideEnd: @MainActor () -> Void = {}

    /// Schedules `work` after `delay`; returns cancel closure.
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

    /// System key-repeat delay, read once per hold.
    var initialDelay: @MainActor () -> TimeInterval = {
        NSEvent.keyRepeatDelay
    }

    /// Whether registrar delivers releases (`HotkeyReleaseReporting`).
    var releaseCapable = false

    /// Preserves outer tally across nested fires.
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
    /// Repeatable command and arguments run on press (`HoldGlide+Ramp.swift`).
    private var fireCommand = ""
    private var fireArgs: [JSONValue] = []

    /// The registration id currently held.
    private(set) var heldID: UInt32?

    /// True from frame-clock start until run end.
    var isGliding = false

    /// True during one glide step write (review 2026-08-29,
    /// `HoldGlideSeamTests`).
    var isApplyingGlideStep = false

    var cancelPending: (() -> Void)?
    var stopFrames: (() -> Void)?
    var glideArgs: [JSONValue] = []
    var glideCommand = ""
    /// Cancels the wall-clock backstop in `HoldGlide+Run`.
    var cancelBackstop: (() -> Void)?
    /// Accumulated simulated frame time for ramp (#611).
    var glideElapsed: TimeInterval = 0

    /// Records executed command tally for eligibility and re-issue.
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

    /// Stops run on size-limit refusal cue (#933, #1055).
    func noteRefusal() {
        refused = true
        cancelRun()
    }

    /// Opens a press fire tally, returning the previous snapshot.
    func beginFire() -> TallySnapshot {
        onFireBegan()
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

    /// Evaluates press tally and schedules glide if eligible.
    func endFire(id: UInt32) {
        let eligible =
            releaseCapable
            && commandsInFire == 1
            && glidableSucceeded
            && !refused
        // New press ends any active run before judging eligibility.
        let command = fireCommand
        let args = fireArgs
        cancelRun()
        guard eligible else { return }
        heldID = id
        glideCommand = command
        glideArgs = args
        // Ramp restarts per press; no speed carryover (designer, 2026-08-29).
        glideElapsed = 0
        cancelPending = schedule(initialDelay()) { [weak self] in
            self?.cancelPending = nil
            self?.beginGlide()
        }
    }

    /// Releases matching held ID; ignores stale IDs.
    func released(id: UInt32) {
        guard heldID == id else { return }
        cancelRun()
    }

    /// Cancels current run and active timers/frames on teardown.
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
        // Notify onGlideEnd only if the glide actually ran, after state reset.
        if wasGliding { onGlideEnd() }
    }
}
