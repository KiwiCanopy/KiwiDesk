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
    /// Draining here is safe under the caller's
    /// display-suppression bracket: `SLSDisableUpdate` defers
    /// *compositing*, not the WindowServer's ordering bookkeeping,
    /// and `CGWindowListCopyWindowInfo` reports a reorder made
    /// inside the bracket ~7 ms later, 3 of 3 (probe on device,
    /// 2026-08-03, macOS 26.6). Without that the drain would be
    /// blind and every landing would burn `landingLimit`.
    ///
    /// Blocking, on the main actor, which no other drain may be —
    /// see `ZOrderDrain.run`. By the time this runs there is no
    /// live session left to block and the gather around it is
    /// already synchronous AX IPC on this actor.
    func restackForTeardown(
        groups: [WindowGather.Group],
        frames: [WindowID: CGRect],
        targetDepth: Int
    ) {
        let deadline =
            ProcessInfo.processInfo.systemUptime
            + Self.teardownRaiseBudget
        // The one window the circle cannot place, dropped from it.
        //
        // A quiet raise cannot get a window above the frontmost
        // app's key window — 0 of 7 over 600 ms, measured for
        // #684, and it is why `raiseFloor` leaves the focused
        // window out of the float raise's floor. Quitting does not
        // change which app is frontmost, so at teardown that key
        // window is usually a circle member: whoever the user was
        // working in, or the terminal they typed `kiwidesk quit`
        // into.
        //
        // Left in, it costs far more than its own slot. Every
        // window the circle puts above it then has a landing
        // condition nothing can satisfy, so each burns
        // `ZOrderDrain.landingLimit` before the drain gives up —
        // the whole budget goes on windows that were never going
        // to verify, and the tail of the circle is issued
        // unverified anyway. Dropped, it stays frontmost (which no
        // raise could change) and every other window verifies
        // against the rest, ignoring it: the drain's landing check
        // is relative and filtered to its own targets, so a window
        // it is not raising cannot fail it. That is also why an
        // UNMANAGED frontmost window needs nothing here — it is
        // already not a member.
        let unbeatable = trustedFrontmostFocusedWindowID()
        for group in groups {
            let remaining =
                deadline - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else {
                // Still the honest sentence it always was: these
                // groups are not raised at all, so their piles
                // keep whatever stacking the moves left them in.
                onLog(
                    "gatherWindows: raise budget exceeded — "
                        + "stacking left partial"
                )
                return
            }
            let pairs = QuitGridLayout.raiseOrder(
                for: group.windows,
                targetDepth: targetDepth
            )
            .filter { frames[$0] != nil && $0 != unbeatable }
            .compactMap { id -> (WindowID, AXUIElement)? in
                eventLoop.element(for: id).map { (id, $0) }
            }
            guard !pairs.isEmpty else { continue }
            let drain = teardownDrain(over: pairs, budget: remaining)
            _ = drain.run(pairs.map(\.0))
            guard
                ProcessInfo.processInfo.systemUptime >= deadline
            else { continue }
            // A different fact from the one above, so it gets a
            // different line: the drain never drops a raise, it
            // issues the rest of the circle without waiting. Those
            // windows were raised — just not verified, which is
            // exactly what every quit did before this drain.
            onLog(
                "gatherWindows: raise budget spent on display "
                    + "\(group.display.raw) — its remaining "
                    + "raises were issued unverified"
            )
        }
    }

    /// The teardown restack's wall clock: the same 1 s the bare
    /// loop it replaced was capped at, spent across every display
    /// group rather than per group.
    ///
    /// Deliberately more than a live restore's
    /// `ZOrderDrain.restoreBudget`, and for the reason the drain's
    /// `budget` states: nothing runs after this to heal a miss, so
    /// it is worth waiting longer here than anywhere else. It is
    /// still a ceiling, because a quit that hangs is worse than a
    /// quit that stacks imperfectly — and it does not raise the
    /// worst case the quit path already accepted, since that loop
    /// could spend the same second on blocking AX IPC alone.
    nonisolated static let teardownRaiseBudget: TimeInterval = 1.0

    /// The drain for one display's circle, with every machine
    /// effect bound to the real one.
    ///
    /// The floor is empty and the staleness seam is constant, and
    /// both are teardown facts rather than shortcuts: the circle's
    /// members are ordered against each other with no plane to
    /// clear (the pile-restore shape), and nothing can supersede a
    /// sequence issued while the app is quitting — there is no
    /// generation left to bump.
    private func teardownDrain(
        over targets: [(WindowID, AXUIElement)],
        budget: TimeInterval
    ) -> ZOrderDrain {
        nonisolated(unsafe) let elements = Dictionary(
            targets,
            uniquingKeysWith: { first, _ in first }
        )
        return ZOrderDrain(
            raise: { id in
                elements[id].map(AXHelper.raiseQuietly)
            },
            stacking: { AXHelper.onScreenStackingOrder() },
            now: { ProcessInfo.processInfo.systemUptime },
            sleep: { Thread.sleep(forTimeInterval: $0) },
            isCurrent: { true },
            floor: [],
            budget: budget
        )
    }
}
