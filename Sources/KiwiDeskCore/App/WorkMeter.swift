import Foundation
import os

/// Counts the work the engine does (#1508): retiles, the frames
/// and parks a pass issues or skips, and every raw AX call with
/// its duration, split by thread. Read and reset through the
/// `cliOnly` `get_work_counters` verb; intervals ride the `work`
/// signpost category for Instruments.
///
/// Thread-safe: AX calls are counted from the per-app frame
/// queues as well as the main actor. A process global because
/// the raw AX call sites are static; a test counting a pass
/// hands the engine its own instance (`TilingEngine.meter`).
public final class WorkMeter: @unchecked Sendable {
    /// The production meter every unwired site records into.
    public static let shared = WorkMeter()

    /// The `work` signpost category (`KiwiLog.subsystem`).
    static let signposter = OSSignposter(
        subsystem: KiwiLog.subsystem,
        category: "work"
    )

    /// Monotonic counts since the last reset. Durations are
    /// nanoseconds.
    public struct Counts: Sendable, Equatable {
        public var events = 0
        public var retiles = 0
        public var retileNanos = 0
        public var retileMaxNanos = 0
        public var reissuePasses = 0
        public var spaceSwitches = 0
        public var barRenders = 0
        public var barNanos = 0
        public var barMaxNanos = 0
        public var borderSyncs = 0
        public var borderNanos = 0
        public var borderMaxNanos = 0
        public var framesIssued = 0
        public var framesSkipped = 0
        public var parksIssued = 0
        public var parksSkipped = 0
        public var framesCoalesced = 0
        public var queuedJobs = 0
        public var queueWaitNanos = 0
        public var queueWaitMaxNanos = 0
        public var axMainCalls = 0
        public var axMainNanos = 0
        public var axMainMaxNanos = 0
        public var axOffMainCalls = 0
        public var axOffMainNanos = 0
    }

    private let lock = NSLock()
    private var counts = Counts()
    private var since: UInt64

    /// Monotonic nanoseconds; replaceable so a test pins time.
    let now: @Sendable () -> UInt64

    public init(
        now: @escaping @Sendable () -> UInt64 = {
            DispatchTime.now().uptimeNanoseconds
        }
    ) {
        self.now = now
        since = now()
    }

    /// Adds `amount` to one counter.
    func add(_ key: WritableKeyPath<Counts, Int>, _ amount: Int = 1) {
        lock.lock()
        defer { lock.unlock() }
        counts[keyPath: key] += amount
    }

    /// Adds a duration to a total, raising its maximum.
    func addDuration(
        _ nanos: Int,
        total: WritableKeyPath<Counts, Int>,
        max: WritableKeyPath<Counts, Int>
    ) {
        lock.lock()
        defer { lock.unlock() }
        counts[keyPath: total] += nanos
        if nanos > counts[keyPath: max] {
            counts[keyPath: max] = nanos
        }
    }

    /// Runs one raw AX call, counting it against the calling
    /// thread. Every `AXUIElement…` call in Core goes through
    /// here (`WorkMeterAXSeamTests`).
    @discardableResult
    func ax<T>(
        isMain: Bool = Thread.isMainThread,
        _ call: () -> T
    ) -> T {
        let start = now()
        let result = call()
        let nanos = Int(clamping: now() &- start)
        lock.lock()
        defer { lock.unlock() }
        if isMain {
            counts.axMainCalls += 1
            counts.axMainNanos += nanos
            if nanos > counts.axMainMaxNanos {
                counts.axMainMaxNanos = nanos
            }
        } else {
            counts.axOffMainCalls += 1
            counts.axOffMainNanos += nanos
        }
        return result
    }

    /// Opens one retile's signpost interval and returns its
    /// close, which records the pass's duration.
    func beginRetile(_ pass: RetilePass) -> () -> Void {
        let id = Self.signposter.makeSignpostID()
        let state = Self.signposter.beginInterval(
            "retile",
            id: id,
            "\(String(describing: pass), privacy: .public)"
        )
        let start = now()
        if pass == .reissue { add(\.reissuePasses) }
        return { [self] in
            Self.signposter.endInterval("retile", state)
            add(\.retiles)
            addDuration(
                Int(clamping: now() &- start),
                total: \.retileNanos,
                max: \.retileMaxNanos
            )
        }
    }

    /// A counted, timed main-actor job.
    enum Span {
        case bars, borders

        var fields:
            (
                count: WritableKeyPath<Counts, Int>,
                total: WritableKeyPath<Counts, Int>,
                max: WritableKeyPath<Counts, Int>
            )
        {
            switch self {
            case .bars: (\.barRenders, \.barNanos, \.barMaxNanos)
            case .borders:
                (\.borderSyncs, \.borderNanos, \.borderMaxNanos)
            }
        }
    }

    /// Starts timing one pass of `span`; the returned call counts
    /// it and records its duration.
    func begin(_ span: Span) -> () -> Void {
        let start = now()
        return { [self] in
            let f = span.fields
            add(f.count)
            addDuration(
                Int(clamping: now() &- start),
                total: f.total,
                max: f.max
            )
        }
    }

    /// Counts one explicit Space switch and marks it on the
    /// signpost timeline.
    func noteSpaceSwitch() {
        add(\.spaceSwitches)
        Self.signposter.emitEvent("space switch")
    }

    /// Stamps a frame job's enqueue; the returned call, run
    /// first on the per-app queue, records how long it waited.
    func queued() -> @Sendable () -> Void {
        let start = now()
        return { [self] in
            add(\.queuedJobs)
            addDuration(
                Int(clamping: now() &- start),
                total: \.queueWaitNanos,
                max: \.queueWaitMaxNanos
            )
        }
    }

    /// The counts and the seconds they cover; `reset` starts a
    /// new window.
    func snapshot(reset: Bool) -> (counts: Counts, seconds: Double) {
        lock.lock()
        defer { lock.unlock() }
        let taken = counts
        let at = now()
        let seconds = Double(at &- since) / 1e9
        if reset {
            counts = Counts()
            since = at
        }
        return (taken, seconds)
    }
}

extension WorkMeter {
    /// The `get_work_counters` reply: raw counts plus the
    /// derived rates #1508 asks for. Milliseconds throughout.
    func report(reset: Bool) -> JSONValue {
        let (c, seconds) = snapshot(reset: reset)
        func ms(_ nanos: Int) -> JSONValue {
            .number((Double(nanos) / 1e4).rounded() / 100)
        }
        func per(_ part: Int, _ whole: Int) -> JSONValue {
            whole == 0
                ? .null
                : .number(
                    (Double(part) / Double(whole) * 100)
                        .rounded() / 100
                )
        }
        func perMs(_ nanos: Int, _ whole: Int) -> JSONValue {
            whole == 0 ? .null : ms(nanos / whole)
        }
        let count: (Int) -> JSONValue = { .number(Double($0)) }
        return .object([
            "seconds": .number((seconds * 100).rounded() / 100),
            "events": count(c.events),
            "retiles": count(c.retiles),
            "retiles_per_second": seconds > 0
                ? .number(
                    (Double(c.retiles) / seconds * 100)
                        .rounded() / 100
                )
                : .null,
            "retile_ms_mean": perMs(c.retileNanos, c.retiles),
            "retile_ms_max": ms(c.retileMaxNanos),
            "events_per_retile": per(c.events, c.retiles),
            "reissue_passes": count(c.reissuePasses),
            "space_switches": count(c.spaceSwitches),
            "bar_renders": count(c.barRenders),
            "bar_ms_mean": perMs(c.barNanos, c.barRenders),
            "bar_ms_max": ms(c.barMaxNanos),
            "bar_renders_per_switch": per(c.barRenders, c.spaceSwitches),
            "border_syncs": count(c.borderSyncs),
            "border_ms_mean": perMs(c.borderNanos, c.borderSyncs),
            "border_ms_max": ms(c.borderMaxNanos),
            "frames_issued": count(c.framesIssued),
            "frames_skipped": count(c.framesSkipped),
            "parks_issued": count(c.parksIssued),
            "parks_skipped": count(c.parksSkipped),
            "frames_coalesced": count(c.framesCoalesced),
            "queued_jobs": count(c.queuedJobs),
            "queue_wait_ms_mean": perMs(
                c.queueWaitNanos,
                c.queuedJobs
            ),
            "queue_wait_ms_max": ms(c.queueWaitMaxNanos),
            "ax_main_calls": count(c.axMainCalls),
            "ax_main_ms_mean": perMs(c.axMainNanos, c.axMainCalls),
            "ax_main_ms_max": ms(c.axMainMaxNanos),
            "ax_main_ms_total": ms(c.axMainNanos),
            "ax_off_main_calls": count(c.axOffMainCalls),
            "ax_off_main_ms_total": ms(c.axOffMainNanos),
            "ax_calls_per_switch": per(
                c.axMainCalls + c.axOffMainCalls,
                c.spaceSwitches
            ),
        ])
    }
}
