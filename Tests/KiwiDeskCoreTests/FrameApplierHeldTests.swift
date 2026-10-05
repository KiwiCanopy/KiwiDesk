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
@Suite("Held writes through the applier (#1956)", .serialized)
@MainActor
struct FrameApplierHeldTests {
    private let w = WindowID(7)
    private let frame = CGRect(x: 10, y: 20, width: 300, height: 200)

    private struct Counts {
        var frames = 0
        var positions = 0
        var eui: [Bool] = []
    }

    private func makeApplier(
        _ counts: OSAllocatedUnfairLock<Counts>
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
        return applier
    }

    private func waitForWrite(
        _ counts: OSAllocatedUnfairLock<Counts>
    ) async throws {
        // A generous guard, never a tight deadline (#344).
        for _ in 0..<500 {
            if counts.withLock({ $0.frames + $0.positions }) > 0 { return }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test("an instant write leaves once, at the landing, under one EUI drop")
    func instantWriteLandsOnce() async throws {
        let counts = OSAllocatedUnfairLock(initialState: Counts())
        let applier = makeApplier(counts)
        applier.holdWrites([w], until: .now() + 0.1)
        applier.applyInstant(w, frame, setSize: false)
        applier.applyInstant(w, frame, setSize: true)
        #expect(applier.held.isStaged(w))
        #expect(counts.withLock { $0.frames + $0.positions } == 0)
        try await waitForWrite(counts)
        try await Task.sleep(for: .milliseconds(100))
        let final = counts.withLock { $0 }
        // Merged: one set, the size kept.
        #expect(final.frames == 1)
        #expect(final.positions == 0)
        #expect(final.eui == [false, true])
        #expect(!applier.held.isStaged(w))
    }

    @Test("an animated frame of a held window waits too")
    func animatedApplyIsHeld() async throws {
        let counts = OSAllocatedUnfairLock(initialState: Counts())
        let applier = makeApplier(counts)
        applier.holdWrites([w], until: .now() + 0.1)
        applier.apply(w, frame, setSize: false)
        #expect(applier.held.isStaged(w))
        try await waitForWrite(counts)
        #expect(counts.withLock { $0.positions } == 1)
    }

    /// A burst holds a staged window again past its first landing:
    /// the first release finds the later deadline, reschedules,
    /// and the write leaves once, no earlier than the second.
    @Test("a window held again lands at the later landing, once")
    func reheldWindowLandsLater() async throws {
        let counts = OSAllocatedUnfairLock(initialState: Counts())
        let applier = makeApplier(counts)
        applier.holdWrites([w], until: .now() + 0.05)
        applier.applyInstant(w, frame, setSize: false)
        let later = DispatchTime.now() + 0.2
        applier.holdWrites([w], until: later)
        try await waitForWrite(counts)
        #expect(counts.withLock { $0.positions } == 1)
        #expect(DispatchTime.now() >= later)
        try await Task.sleep(for: .milliseconds(100))
        #expect(counts.withLock { $0.positions } == 1)
    }

    @Test("releasing a hold sends its write now")
    func releaseSendsNow() async throws {
        let counts = OSAllocatedUnfairLock(initialState: Counts())
        let applier = makeApplier(counts)
        applier.holdWrites([w], until: .now() + 60)
        applier.applyInstant(w, frame, setSize: false)
        applier.releaseAllHolds()
        try await waitForWrite(counts)
        #expect(counts.withLock { $0.positions } == 1)
    }

    @Test("a quit drops every held write")
    func dropAllForgets() {
        let applier = makeApplier(
            OSAllocatedUnfairLock(initialState: Counts())
        )
        applier.holdWrites([w], until: .now() + 60)
        applier.applyInstant(w, frame, setSize: false)
        applier.held.dropAll()
        #expect(!applier.held.isStaged(w))
        #expect(!applier.held.isHeld(w))
    }
}
