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
    /// budget below. Holding the freeze across those waits would
    /// trade one composite for a frozen screen. `gatherWindows`
    /// therefore resumes before calling this.
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
        // `stop()` also runs mid-session when the AX permission is
        // REVOKED (`KiwiCore+Lifecycle`), and that path must not
        // reach the drain. Every raise there returns
        // `kAXErrorAPIDisabled` and lands nothing, while
        // `onScreenStackingOrder` keeps answering — it reads
        // `CGWindowList`, which needs no AX grant — so the drain
        // is not blind, it is merely never satisfied: it would
        // plan the whole circle and spend the entire budget
        // sleeping on the main actor for landings that cannot
        // come. The loop this replaced cost nothing there, so the
        // gate is not an optimization, it is the regression's fix
        // (code review, 2026-08-03). The moves pass ahead of it is
        // already a silent no-op under revocation, as its own
        // docstring says.
        guard AXHelper.isTrusted() else {
            onLog(
                "gatherWindows: no Accessibility permission — "
                    + "skipping the raise circle"
            )
            return
        }
        // One reference to the teardown policy, so the whole-quit
        // deadline and every group's drain cannot be sized from
        // different things.
        let policy = ZOrderDrain.Policy.teardown
        let deadline =
            ProcessInfo.processInfo.systemUptime + policy.budget
        // The one window the circle cannot place, dropped from it.
        //
        // A quiet raise cannot get a window above the frontmost
        // app's key window — the measurement, and why the float
        // raise answers the same constraint by keeping that window
        // out of its FLOOR instead, are on `raiseFloor`. Quitting
        // does not change which app is frontmost, so here that key
        // window is usually a circle member: whichever app the
        // user was working in when they quit KiwiDesk, including
        // the terminal, if that is where they stopped it from.
        //
        // Left in, it costs far more than its own slot. Every
        // window the circle puts above it then has a landing
        // condition nothing can satisfy, so each burns
        // `ZOrderDrain.landingLimit` before the drain gives up and
        // the budget goes on windows that were never going to
        // verify. Dropped, it stays frontmost (which no raise
        // could change) and every other window verifies against
        // the rest, ignoring it: the drain's landing check is
        // relative and filtered to its own targets, so a window it
        // is not raising cannot fail it. That is also why an
        // UNMANAGED frontmost window needs nothing here — it is
        // already not a member.
        //
        // Nil is the ordinary answer, not a failure: no frontmost
        // app, one showing an ignored panel (#21), or an AX read
        // that did not answer. Then nothing is dropped and the
        // burn above is what a quit pays — bounded by the budget,
        // and not worth a log line on every quit that had no
        // managed window in front.
        let unbeatable = trustedFrontmostFocusedWindowID()
        for group in groups {
            let remaining =
                deadline - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else {
                // Still the honest sentence it always was: these
                // groups are not raised at all, so their piles
                // keep whatever stacking the moves left them in.
                //
                // The same answer the drain gives its own tail
                // (`spendsBudgetOnUnverifiedTail: false` below),
                // and for the same reason rather than by accident:
                // once the wall clock is spent, issuing anything
                // costs a blocking AX call per window that the
                // budget has no room left to pay for. Dropping is
                // what the loop this replaced did at exactly this
                // boundary.
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
            let order = pairs.map(\.0)
            let drain = teardownDrain(
                over: pairs,
                policy: policy.limited(to: remaining)
            )
            let raised = drain.run(order)
            // A different fact from the one above, so it gets a
            // different line: this display's circle was started
            // and stopped part way, so the windows it never
            // reached keep whatever stacking the moves left them.
            //
            // NOT `raised.count < order.count`: the drain raises
            // only what is out of place, so raising fewer than the
            // circle names is its ordinary success, not a
            // shortfall. The signal is the clock, which is exact
            // here precisely because this drain drops its tail —
            // with `spendsBudgetOnUnverifiedTail: false` the only
            // way `run` returns is a finished plan or a spent
            // budget. `!raised.isEmpty` removes the one false
            // positive that leaves: an already-correct group
            // returns after a single ~0.4 ms read having raised
            // nothing, and would otherwise claim a shortfall if
            // that read crossed the deadline (code review,
            // It still over-reports a drain that finished its
            // whole plan right at the deadline, and that window is
            // `landingLimit` wide rather than one poll interval:
            // `awaitLanding` caps its own wait at the deadline, so
            // a last element reached with less than that left can
            // complete the plan with the clock sitting on it
            // (code review, 2026-08-03). What neither line can see is the
            // drain's failed-read branch, which issues a whole
            // circle blind in microseconds — `ZOrderDrain`'s to
            // report if it ever earns a line.
            guard
                !raised.isEmpty,
                ProcessInfo.processInfo.systemUptime >= deadline
            else { continue }
            onLog(
                "gatherWindows: raise budget spent on display "
                    + "\(group.display.raw) after \(raised.count) "
                    + "raise(s) — the rest of its circle was left "
                    + "in place"
            )
        }
    }

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
        policy: ZOrderDrain.Policy
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
            policy: policy
        )
    }
}
