import ApplicationServices
import CoreGraphics
import Foundation

extension KiwiCore {
    /// The quit grid's raise circle, drained (#688).
    ///
    /// The frames alone cannot guarantee readable piles — whatever
    /// z-order existed at quit would decide which title bars
    /// survive — so `QuitGridLayout.raiseOrder` defines the
    /// stacking instead: cell by cell, each pile top slot first
    /// and deepest last, so pile order holds within every cell and
    /// later cells sit above earlier ones.
    ///
    /// It used to issue that circle as a bare loop of
    /// `AXHelper.raiseQuietly`, which does not produce it.
    /// `AXUIElementPerformAction(kAXRaiseAction)` returns once the
    /// app has *accepted* the raise, not once it has performed it,
    /// so the whole circle went out while none of it had happened
    /// and the apps landed it in whatever order they reached it
    /// (`ZOrderDrain` carries the measurement). Every other raise
    /// sequence now goes through the drain; this one is the reason
    /// it must: it is the last thing that runs before management
    /// stops, so there is no later restore to diff against reality
    /// and put a miss right. What the user is left looking at is
    /// whatever this leaves.
    ///
    /// This function is the WIRING only — the machine seams bound
    /// to the real machine. `TeardownRestack` owns what is done
    /// with them, so the Accessibility gate, the dropped window,
    /// the per-group budget and the stop-dead boundary are
    /// unit-tested rather than watched by a source scan
    /// (`TeardownRestackTests`).
    ///
    /// Runs OUTSIDE the caller's display-suppression bracket, and
    /// that is a decision, not an accident. It could run inside:
    /// `SLSDisableUpdate` defers *compositing*, not the
    /// WindowServer's ordering bookkeeping, and
    /// `CGWindowListCopyWindowInfo` reports a reorder made inside
    /// the bracket ~7 ms later, 3 of 3 (probe on device,
    /// 2026-08-03, macOS 26.6) — so the drain would not be blind
    /// there. But the bracket freezes compositing for the whole
    /// desktop, and this pass no longer costs the few milliseconds
    /// a bare raise loop did: it waits for landings, up to the
    /// budget. Holding the freeze across those waits would trade
    /// one composite for a frozen screen. `gatherWindows`
    /// therefore resumes before calling this.
    ///
    /// Blocking, on the main actor, which no other drain may be —
    /// see `ZOrderDrain.run`. By the time this runs there is no
    /// live session left to block and the gather around it is
    /// already synchronous AX IPC on this actor.
    func restackForTeardown(
        groups: [WindowGather.Group],
        frames: [WindowID: CGRect],
        targetDepth: Int,
        unbeatable: WindowID?
    ) {
        let circles = groups.map { group in
            (
                display: group.display.raw,
                order: QuitGridLayout.raiseOrder(
                    for: group.windows,
                    targetDepth: targetDepth
                )
                .filter { frames[$0] != nil }
            )
        }
        TeardownRestack(
            isTrusted: { AXHelper.isTrusted() },
            // The one window the circle cannot place — resolved
            // by `gatherWindows` and handed in, because the grid
            // ALSO uses it: it is placed last in its cell so that
            // being in front is the slot it was given, rather than
            // a defect (`WindowGather.collect`). Two views of one
            // fact, so they read one value.
            //
            // A quiet raise cannot get a window above the frontmost
            // app's key window — the measurement, and why the float
            // raise answers the same constraint by keeping that
            // window out of its FLOOR instead, are on `raiseFloor`.
            // Dropping it from the circle costs nothing now: it is
            // already where the circle would have raised it to.
            //
            // Nil is the ordinary answer, not a failure: no
            // frontmost app, one showing an ignored panel (#21), or
            // an AX read that did not answer.
            unbeatable: { unbeatable },
            now: { ProcessInfo.processInfo.systemUptime },
            drain: { [weak self] order, policy in
                self?.teardownDrain(over: order, policy: policy)
            },
            log: { [weak self] message in self?.onLog(message) },
            policy: .teardown
        )
        .run(circles)
    }

    /// The drain for one display's circle, with every machine
    /// effect bound to the real one. Nil when not one window of the
    /// circle has a reachable AX element.
    ///
    /// The floor is empty and the staleness seam is constant, and
    /// both are teardown facts rather than shortcuts: the circle's
    /// members are ordered against each other with no plane to
    /// clear (the pile-restore shape), and nothing can supersede a
    /// sequence issued while the app is quitting — there is no
    /// generation left to bump.
    private func teardownDrain(
        over order: [WindowID],
        policy: ZOrderDrain.Policy
    ) -> ZOrderDrain? {
        nonisolated(unsafe) let elements = Dictionary(
            order.compactMap { id -> (WindowID, AXUIElement)? in
                eventLoop.element(for: id).map { (id, $0) }
            },
            uniquingKeysWith: { first, _ in first }
        )
        guard !elements.isEmpty else { return nil }
        return ZOrderDrain(
            raise: { id in
                elements[id].map(AXHelper.raiseQuietly)
            },
            stacking: { AXHelper.onScreenStackingOrder() },
            now: { ProcessInfo.processInfo.systemUptime },
            sleep: { Thread.sleep(forTimeInterval: $0) },
            isCurrent: { true },
            floor: [],
            policy: policy
        )
    }
}
