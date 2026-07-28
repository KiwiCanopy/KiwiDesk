import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
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
        let keys: [DeferredTasks.Key] = [
            .focusFollow, .startupSweep,
            .spaceSettle, .nativeSpaceSettle,
            .borderDropSettle, .borderResync,
        ]
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
}
