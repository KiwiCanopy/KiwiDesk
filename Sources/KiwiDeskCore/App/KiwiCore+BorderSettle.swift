import Foundation

/// The two ring settle passes (borders.md ▸ Two settle passes):
/// visibility early, geometry late, each on its own deferred key.
/// Both re-stack every ring, which a steady retile no longer does
/// (#1925).
extension KiwiCore {
    /// How long after the animation clock settles the overlays are
    /// re-synced from real window state (#596). Not a guess at the
    /// motion's length — the settle signal already tells us that —
    /// but at how long a slow-AX app keeps applying queued frames
    /// past it (100–300 ms on Electron/WebKit; 213 ms measured on
    /// device for a frozen-then-resumed app). Reading sooner reads
    /// bounds the app has not caught up to, which is the backward
    /// snap this issue is about; reading later costs nothing in
    /// the common case, because the post-settle AX echoes are
    /// already walking the overlay onto the real frame — this pass
    /// is the backstop for the app that sends no echo at all.
    /// No mutable seam sits beside it: `runBorderResync` is
    /// directly callable, so a test drives the body rather than
    /// waiting the delay out.
    static let borderResyncDelayMS = 300

    /// WindowServer can briefly order the swap target out while a
    /// drag/drop retile and focus raise overlap. Its hide
    /// notification hides that target's ring, but macOS does not
    /// always send a matching unhide. Re-assert the complete
    /// desired ring set once the swap animation is well under way
    /// (or one short event turn later when nothing animates).
    ///
    /// This is the VISIBILITY pass, and it is deliberately early:
    /// `sync`'s trailing `order(relativeTo:)` is what un-hides a
    /// ring, so the sooner it runs the shorter a wrongly-hidden
    /// ring stays invisible. Landing mid-flight used to make it
    /// the backward snap of #596 item 3 — it no longer can,
    /// because `FollowSource.syncFrame` holds the geometry of a
    /// window OUR OWN animation is driving, so this pass
    /// re-orders and un-hides without moving that window's ring.
    /// (It still re-reads state for every non-animating ring in
    /// the space, as every retile's `updateBorders()` does — but
    /// only this pass re-stacks a ring already shown, #1925.)
    ///
    /// That is why both passes exist: this one restores
    /// VISIBILITY early and cannot fix an animating window's
    /// geometry; `scheduleBorderResync` fixes GEOMETRY late and
    /// would be far too slow for a hidden ring. Separate deferred
    /// keys, so neither can cancel the other.
    func scheduleBorderDropReconcile() {
        let animationMS =
            tiler.animation.activeCount > 0
            ? tiler.settings.animations.durationMS : 0
        deferred.schedule(
            .borderDropSettle,
            after: .milliseconds(animationMS + 50)
        ) { [weak self] in
            self?.updateBorders(reassertOrder: true)
        }
    }

    /// Re-syncs both overlay families from real window state a
    /// grace after the last animation ends — the heal for a window
    /// whose app accepted no AX write during the flight (#596
    /// item 2). The ring rode our commanded per-tick frames to the
    /// target while the window never moved, and with no echo and
    /// no WindowServer event there is nothing else to correct it;
    /// this pass reads the state the window actually has and glues
    /// the ring and mark back onto it.
    func scheduleBorderResync() {
        deferred.schedule(
            .borderResync,
            after: .milliseconds(Self.borderResyncDelayMS)
        ) { [weak self] in
            self?.runBorderResync()
        }
    }

    /// The re-sync body. Named rather than inlined so a test can
    /// drive it directly instead of waiting out the grace.
    ///
    /// Deliberately UNGATED on the animation count. The obvious
    /// guard — bail if something started animating inside the
    /// grace — discards the whole pass because of ONE window,
    /// stranding every other window that did settle. Nothing is
    /// bought by it: `FollowSource.syncFrame` already refuses to
    /// move a window our animation is driving, per window, which
    /// is what the count was standing in for. That is the general
    /// shape — never gate on the global count as a proxy for a
    /// per-window question. (Waiting on the count for a genuinely
    /// global precondition is a different thing and stays
    /// correct: the z-order restore and the deferred focus raise
    /// both do it, because a raise issued while any frames are
    /// still landing arrives late on slow apps.)
    ///
    /// The cost of running early is one read of a window that
    /// settled seconds ago, and the in-flight animation's own
    /// settle arms another pass behind it.
    ///
    /// Ungating does NOT, by itself, survive an animation that
    /// never settles: the arming path sits behind the same
    /// signal — `notifyIfIdle` only fires `onAllAnimationsEnded`
    /// at `activeCount == 0` — so this pass would never be
    /// scheduled, gate or no gate, and the same held for the
    /// deferred focus raise and the z-order restore. That was
    /// always the engine's to fix, and #599 fixed the known
    /// cause; the shape of the exposure is why this stays
    /// ungated rather than growing a second guard.
    func runBorderResync() {
        updateBorders(reassertOrder: true)
        updateStickyMarks(reassertOrder: true)
    }
}
