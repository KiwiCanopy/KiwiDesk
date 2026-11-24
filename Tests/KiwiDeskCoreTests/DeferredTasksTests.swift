import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory =
        testTemporaryDirectory
        .appendingPathComponent(
            "kiwidesk-deferred-tests-\(UUID().uuidString)"
        )
    return makeTestCore(configDirectory: directory)
}

/// The keyed owner of KiwiCore's one-shot settle tasks (#49).
/// Tests await the stored task handles instead of sleeping
/// fixed buffers, so they stay deterministic.
@MainActor
struct DeferredTasksTests {
    @Test("A scheduled body fires after its delay")
    func schedulesAndFires() async {
        let owner = DeferredTasks()
        var fired = false
        owner.schedule(.spaceSettle, after: .milliseconds(5)) {
            fired = true
        }
        await owner.task(for: .spaceSettle)?.value
        #expect(fired)
    }

    @Test("Rescheduling a key cancels and replaces the prior")
    func reschedulingReplacesThePrior() async {
        let owner = DeferredTasks()
        var winner = 0
        owner.schedule(.spaceSettle, after: .milliseconds(5)) {
            winner = 1
        }
        let first = owner.task(for: .spaceSettle)
        owner.schedule(.spaceSettle, after: .milliseconds(5)) {
            winner = 2
        }
        let second = owner.task(for: .spaceSettle)
        #expect(first?.isCancelled == true)
        #expect(second != first)
        await first?.value
        await second?.value
        #expect(winner == 2)
    }

    @Test("cancel(_:) prevents the body and clears the slot")
    func cancelPreventsTheBody() async {
        let owner = DeferredTasks()
        var fired = false
        owner.schedule(.focusFollow, after: .milliseconds(5)) {
            fired = true
        }
        let task = owner.task(for: .focusFollow)
        owner.cancel(.focusFollow)
        await task?.value
        #expect(!fired)
        #expect(owner.task(for: .focusFollow) == nil)
    }

    @Test("Keys are independent slots")
    func keysAreIndependent() async {
        let owner = DeferredTasks()
        var focusFired = false
        var sweepFired = false
        owner.schedule(.focusFollow, after: .milliseconds(5)) {
            focusFired = true
        }
        owner.schedule(.startupSweep, after: .milliseconds(5)) {
            sweepFired = true
        }
        let cancelled = owner.task(for: .focusFollow)
        owner.cancel(.focusFollow)
        await cancelled?.value
        await owner.task(for: .startupSweep)?.value
        #expect(!focusFired)
        #expect(sweepFired)
    }

    @Test("cancelAll sweeps every pending key")
    func cancelAllSweepsEveryKey() async {
        let owner = DeferredTasks()
        var fired = false
        let body: @MainActor () -> Void = { fired = true }
        // Discovered, not enumerated: a hand-listed sweep is one
        // more place to forget a new key (parity-tests.md prefers
        // discovery for exactly this reason).
        let keys = DeferredTasks.Key.allCases
        for key in keys {
            owner.schedule(key, after: .milliseconds(5), body)
        }
        let pending = keys.compactMap { owner.task(for: $0) }
        #expect(pending.count == keys.count)
        owner.cancelAll()
        for task in pending {
            await task.value
        }
        #expect(!fired)
        for key in keys {
            #expect(owner.task(for: key) == nil)
        }
    }

    @Test("A cancelled key can be rescheduled afterwards")
    func cancelledKeyReschedules() async {
        let owner = DeferredTasks()
        var fired = false
        owner.schedule(.spaceSettle, after: .milliseconds(5)) {}
        owner.cancel(.spaceSettle)
        owner.schedule(.spaceSettle, after: .milliseconds(5)) {
            fired = true
        }
        await owner.task(for: .spaceSettle)?.value
        #expect(fired)
    }

    @Test("stop() cancels a pending settle via cancelAll")
    func stopCancelsPendingSettles() {
        let core = makeCore()
        core.execute(
            "focus_space",
            args: [.string("2")]
        )
        let settle = core.deferred.task(for: .spaceSettle)
        #expect(settle != nil)
        core.stop()
        #expect(settle?.isCancelled == true)
        #expect(core.deferred.task(for: .spaceSettle) == nil)
    }

    /// The waits one schedule asked for, noted from its task.
    private final class Sleeps: @unchecked Sendable {
        private let lock = NSLock()
        private var waits: [Duration] = []
        func note(_ wait: Duration) {
            lock.withLock { waits.append(wait) }
        }
        var all: [Duration] { lock.withLock { waits } }
    }

    /// Every wait parks until its slot is replaced, so only the cap
    /// fires mid-stream; the 30 ms gaps are floors a slow runner
    /// only widens (#3567).
    @Test("maxWait forces execution during a continuous burst")
    func maxWaitForcesExecution() async {
        let owner = DeferredTasks()
        owner.sleep = { _ in try? await Task.sleep(for: .seconds(3_600)) }
        var fireCount = 0
        let body: @MainActor () -> Void = { fireCount += 1 }
        func reschedule() {
            owner.schedule(
                .barTitleRefresh,
                after: .milliseconds(100),
                maxWait: .milliseconds(120),
                body
            )
        }
        reschedule()
        for _ in 1...10 {
            try? await Task.sleep(for: .milliseconds(30))
            reschedule()
        }
        // No wait has ended, so every fire so far is the cap's; a
        // cap fire opens a fresh burst, so 11 calls cap at most 5.
        #expect(fireCount >= 1)
        #expect(fireCount <= 5)
        let capped = fireCount
        owner.sleep = { _ in }
        reschedule()
        await owner.task(for: .barTitleRefresh)?.value
        #expect(fireCount == capped + 1)
    }

    /// A burst's later wait is clamped to what is left of its cap;
    /// an hour-long cap no runner reaches, so a slow run only
    /// shortens what is left (#3567).
    @Test("A rescheduled wait is clamped to the cap's remainder")
    func rescheduleClampsToTheCap() async {
        let owner = DeferredTasks()
        let sleeps = Sleeps()
        owner.sleep = { wait in
            sleeps.note(wait)
            try? await Task.sleep(for: .seconds(3_600))
        }
        func reschedule() {
            owner.schedule(
                .barTitleRefresh,
                after: .seconds(3_600),
                maxWait: .seconds(3_600)
            ) {}
        }
        reschedule()
        try? await Task.sleep(for: .milliseconds(50))
        reschedule()
        let last = owner.task(for: .barTitleRefresh)
        #expect(last != nil)
        owner.cancelAll()
        await last?.value
        let waits = sleeps.all.sorted()
        let aged = Duration.seconds(3_600) - .milliseconds(50)
        #expect(waits.count == 2)
        #expect(waits.first.map { $0 <= aged } == true)
        #expect(waits.last.map { $0 > .seconds(3_599) } == true)
    }

    /// A long wait parks until its cancel and a short one lands, so
    /// no verdict reads how fast the runner reached it (#3567).
    @Test("cancel() clears the maxWait burst tracking")
    func cancelClearsBurstTracking() async {
        let owner = DeferredTasks()
        let sleeps = Sleeps()
        owner.sleep = { wait in
            sleeps.note(wait)
            guard wait > .seconds(1) else { return }
            try? await Task.sleep(for: .seconds(3_600))
        }
        var fired = false
        owner.schedule(
            .barTitleRefresh,
            after: .seconds(2),
            maxWait: .seconds(3)
        ) {
            fired = true
        }
        // Ages the burst start past 250 ms, the slack a correct
        // reschedule's own clock reads get; a slow runner only ages
        // it further.
        try? await Task.sleep(for: .milliseconds(250))
        owner.cancel(.barTitleRefresh)
        #expect(!fired)

        // An inherited start would cut this wait below its 100 ms
        // delay, or fire the body at once.
        owner.schedule(
            .barTitleRefresh,
            after: .milliseconds(100),
            maxWait: .milliseconds(350)
        ) {
            fired = true
        }
        let rescheduled = owner.task(for: .barTitleRefresh)
        #expect(rescheduled != nil, "must not inherit pre-cancel burst")
        await rescheduled?.value
        #expect(fired)
        #expect(sleeps.all.sorted() == [.milliseconds(100), .seconds(2)])
    }
}
