import ApplicationServices
import CoreGraphics
import Foundation
import Testing
import os

@testable import KiwiDeskCore

/// A held write through the applier (#1956): staged while the hold
/// stands, sent ONCE from the app's own queue at the landing,
/// inside one Enhanced UI drop and restore, by both write paths.
/// The element names a pid nothing writes to; the writer counts.
/// The hold's clock and its landing are the test's (#3594): the
/// live landing fires off main at a wall-clock deadline, so an
/// assertion made before it raced a starved runner.
@Suite("Held writes through the applier (#1956)", .serialized)
@MainActor
struct FrameApplierHeldTests {
    private let w = WindowID(7)
    private let frame = CGRect(x: 10, y: 20, width: 300, height: 200)

    private struct Counts {
        var frames = 0
        var positions = 0
        var eui: [Bool] = []
        var written: Int { frames + positions }
    }

    /// The hold's clock and the landings it scheduled, run by hand.
    private final class Landings: @unchecked Sendable {
        var now = DispatchTime(uptimeNanoseconds: 1_000_000_000)
        var owed: [(DispatchTime, @Sendable () -> Void)] = []

        func after(_ seconds: Double) -> DispatchTime {
            now + seconds
        }

        /// Steps the clock to `deadline` and runs every landing due
        /// by then, in deadline order.
        func land(at deadline: DispatchTime) {
            now = deadline
            let due = owed.filter { $0.0 <= deadline }
            owed.removeAll { $0.0 <= deadline }
            for (_, landing) in due.sorted(by: { $0.0 < $1.0 }) {
                landing()
            }
        }
    }

    private func makeApplier(
        _ counts: OSAllocatedUnfairLock<Counts>,
        _ landings: Landings
    ) -> FrameApplier {
        let applier = FrameApplier()
        let element = AXUIElementCreateApplication(1)
        applier.elementProvider = { _ in element }
        applier.enhancedUIAtRest = { _ in true }
        applier.writer = FrameWriter(
            setFrame: { _, _ in counts.withLock { $0.frames += 1 } },
            setPosition: { _, _ in counts.withLock { $0.positions += 1 } },
            writeEUI: { _, on in counts.withLock { $0.eui.append(on) } }
        )
        applier.heldNow = { landings.now }
        applier.scheduleHeldLanding = { _, delay, landing in
            landings.owed.append((landings.after(delay), landing))
        }
        return applier
    }

    /// A held set owes no #2187 resend: it lands once, at the
    /// landing, and nothing schedules a second write (#2524).
    @Test("a held cross-screen set owes no resend")
    func heldSetOwesNoResend() {
        let counts = OSAllocatedUnfairLock(initialState: Counts())
        let landings = Landings()
        let applier = makeApplier(counts, landings)
        var owed: [@MainActor () -> Void] = []
        applier.scheduleResend = { _, work in owed.append(work) }
        let landing = landings.after(0.05)
        applier.holdWrites([w], for: 0.05)
        applier.applyInstant(w, frame, setSize: true, resend: true)
        landings.land(at: landing)
        #expect(owed.isEmpty)
        #expect(counts.withLock { $0.frames } == 1)
    }

    @Test("an instant write leaves once, at the landing, under one EUI drop")
    func instantWriteLandsOnce() {
        let counts = OSAllocatedUnfairLock(initialState: Counts())
        let landings = Landings()
        let applier = makeApplier(counts, landings)
        let landing = landings.after(0.1)
        applier.holdWrites([w], for: 0.1)
        applier.applyInstant(w, frame, setSize: false)
        applier.applyInstant(w, frame, setSize: true)
        #expect(applier.held.isStaged(w))
        #expect(counts.withLock { $0.written } == 0)
        #expect(landings.owed.count == 1, "one landing for the merge")
        landings.land(at: landing)
        let final = counts.withLock { $0 }
        // Merged: one set, the size kept.
        #expect(final.frames == 1)
        #expect(final.positions == 0)
        #expect(final.eui == [false, true])
        #expect(!applier.held.isStaged(w))
        #expect(landings.owed.isEmpty, "nothing lands a second time")
    }

    @Test("an animated frame of a held window waits too")
    func animatedApplyIsHeld() {
        let counts = OSAllocatedUnfairLock(initialState: Counts())
        let landings = Landings()
        let applier = makeApplier(counts, landings)
        let landing = landings.after(0.1)
        applier.holdWrites([w], for: 0.1)
        applier.apply(w, frame, setSize: false)
        #expect(applier.held.isStaged(w))
        #expect(counts.withLock { $0.written } == 0)
        landings.land(at: landing)
        #expect(counts.withLock { $0.positions } == 1)
    }

    /// A burst holds a staged window again past its first landing:
    /// the first release finds the later deadline, reschedules,
    /// and the write leaves once, no earlier than the second.
    @Test("a window held again lands at the later landing, once")
    func reheldWindowLandsLater() async throws {
        let counts = OSAllocatedUnfairLock(initialState: Counts())
        let landings = Landings()
        let applier = makeApplier(counts, landings)
        let first = landings.after(0.05)
        applier.holdWrites([w], for: 0.05)
        applier.applyInstant(w, frame, setSize: false)
        let later = landings.after(0.2)
        applier.holdWrites([w], for: 0.2)
        landings.land(at: first)
        #expect(counts.withLock { $0.written } == 0)
        // The reschedule hops through the main queue once.
        for _ in 0..<500 where landings.owed.isEmpty {
            await Task.yield()
        }
        try #require(landings.owed.map(\.0) == [later])
        landings.land(at: later)
        #expect(counts.withLock { $0.positions } == 1)
        #expect(landings.owed.isEmpty)
    }

    /// The loop let go of the app before the landing: the write
    /// still leaves, and toggles nothing on an app no longer owned.
    @Test("a release after the app's retire toggles no EUI")
    func retiredAppTakesNoHold() {
        let counts = OSAllocatedUnfairLock(initialState: Counts())
        let landings = Landings()
        let applier = makeApplier(counts, landings)
        let landing = landings.after(0.1)
        applier.holdWrites([w], for: 0.1)
        applier.applyInstant(w, frame, setSize: false)
        applier.retireApp(1, leftOn: true)
        landings.land(at: landing)
        #expect(counts.withLock { $0.positions } == 1)
        #expect(counts.withLock { $0.eui }.isEmpty)
    }

    @Test("releasing a hold sends its write now")
    func releaseSendsNow() {
        let counts = OSAllocatedUnfairLock(initialState: Counts())
        let landings = Landings()
        let applier = makeApplier(counts, landings)
        applier.holdWrites([w], for: 60)
        applier.applyInstant(w, frame, setSize: false)
        applier.releaseAllHolds()
        landings.land(at: landings.now)
        #expect(counts.withLock { $0.positions } == 1)
    }

    @Test("a quit drops every held write")
    func dropAllForgets() {
        let landings = Landings()
        let applier = makeApplier(
            OSAllocatedUnfairLock(initialState: Counts()),
            landings
        )
        applier.holdWrites([w], for: 60)
        applier.applyInstant(w, frame, setSize: false)
        applier.held.dropAll()
        #expect(!applier.held.isStaged(w))
        #expect(!applier.held.isHeld(w, now: landings.now))
    }
}
