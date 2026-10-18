import ApplicationServices
import Foundation

/// A Desktop switch's bulk re-sync, read OFF the main actor
/// (#2347): one list read per gated app, applied in ONE switch
/// fold once every read has landed or the bound has passed. Kept
/// on `OffMainReconcile`, whose stop drops it with every debt.
struct SwitchReconcile {
    /// One app's read for the open batch.
    struct Read {
        let app: AppRef
        let tracked: Set<WindowID>
        let writesAtRead: Int
        /// When it was asked; the reading carries when it RAN.
        let started: ContinuousClock.Instant
        var reading: WindowListReading?
        var applied = false
    }

    struct Batch {
        let generation: Int
        /// The gate's order, which the apply keeps.
        var order: [pid_t] = []
        var reads: [pid_t: Read] = [:]
        /// The fold of what landed by the bound, or of every read,
        /// has run; a later read applies alone.
        var mainApplied = false
    }

    /// The bound on the batch's one fold: past it, what landed
    /// applies and a straggler applies alone. Under the switch
    /// grace (`EventLoop.spaceSwitchCoalesceGrace`) and the 600 ms
    /// settle, so neither waits on one slow app.
    static let bound: TimeInterval = 0.4
    /// A straggler asked longer ago than this is re-read instead,
    /// since the carried arm's in-flight span no longer covers a
    /// carried window it misses; kept under `KiwiCore
    /// .inFlightWindow` by a margin for the carry's stamp, which
    /// lands in the handler ahead of the ask.
    static let stragglerLimit: TimeInterval = 4.5

    var generation = 0
    var batch: Batch?
    /// Per app, when the read behind its newest applied reconcile
    /// began; a batch read begun before it answers nothing.
    private(set) var appliedRead: [pid_t: ContinuousClock.Instant] = [:]
    /// An off-main apply landing for an app the batch still awaits,
    /// with when its read ran: it applies inside the fold, in read
    /// order, so the batch's one pass places it.
    struct Held {
        let start: ContinuousClock.Instant
        let apply: @MainActor () -> Void
    }

    /// Kept across a superseding switch, run by the next fold.
    var held: [Held] = []
    /// Work owed after the next fold, in order — the switch's
    /// public event, whose consumers re-query the arrivals.
    var afterFold: [@MainActor () -> Void] = []
    /// The batch's fold is applying: its arrivals are switch
    /// reveals, never a launch's window (#1599).
    var applying = false
    /// The Desktop settle owed once the batch's fold has run: one
    /// slot, latest wins (#49), emptied by the next switch.
    var parkedSettle: (@MainActor () -> Void)?
    /// A bar refresh asked while the batch was pending.
    var barsOwed = false
    typealias Work = @MainActor @Sendable () -> Void
    /// Runs `work` after `delay` on the main actor; injected in
    /// tests.
    var scheduleBound: @MainActor (TimeInterval, @escaping Work) -> Void = {
        delay,
        work in
        DispatchQueue.main.asyncAfter(
            deadline: .now() + delay,
            execute: work
        )
    }
    /// The batch's fold has run: the core pays the bars it held.
    var onApplied: @MainActor () -> Void = {}

    /// A switch's fold has not run yet: its arrivals and
    /// departures are still unapplied.
    var isPending: Bool { batch.map { !$0.mainApplied } ?? false }

    /// An app whose switch read has not applied.
    func isOutstanding(_ pid: pid_t) -> Bool {
        batch?.reads[pid].map { !$0.applied } ?? false
    }

    /// An off-main apply for `pid` waits for the fold.
    func holdsApply(_ pid: pid_t) -> Bool {
        isPending && isOutstanding(pid)
    }

    mutating func noteApplied(
        _ pid: pid_t,
        readAt: ContinuousClock.Instant
    ) {
        if let last = appliedRead[pid], last >= readAt { return }
        appliedRead[pid] = readAt
    }

    /// A reading begun at `start` is older than one applied.
    func answeredSince(_ pid: pid_t, _ start: ContinuousClock.Instant)
        -> Bool
    {
        appliedRead[pid].map { $0 > start } ?? false
    }

    mutating func forget(_ pid: pid_t) { appliedRead[pid] = nil }

    /// Forgets the batch and what waits on it, at a stop; the
    /// generation stays, so a read from before answers nothing.
    mutating func drop() {
        batch = nil
        held = []
        afterFold = []
        applying = false
        parkedSettle = nil
        barsOwed = false
        appliedRead = [:]
    }
}
