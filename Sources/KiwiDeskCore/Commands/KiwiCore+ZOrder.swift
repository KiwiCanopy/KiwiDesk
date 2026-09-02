import AppKit
import Foundation

/// Serial queue for z-order raises. AX raise calls are blocking
/// IPC, and the drain that runs on top of them blocks further
/// still while it waits for each raise to land, so both belong
/// off the main thread. The queue keeps the sequence serial; what
/// keeps the resulting STACKING in order is `ZOrderDrain` — the
/// call itself returns before the app performs the raise (#684).
let zOrderQueue = DispatchQueue(
    label: "org.kiwidesk.zorder",
    qos: .userInteractive
)

/// Z-order maintenance for the layouts whose windows overlap:
/// stack's cascade and scrolling's edge piles.
extension KiwiCore {
    /// Requests a z-order restore after something scrambled
    /// the stacking (zone crossings, mode switches, native
    /// space switches, profile loads). Deferred until all
    /// animations settle: a raise is only processed once the
    /// target app's main thread is free, and while frames are
    /// still being applied, slow apps process their raise
    /// late and end up out of order.
    ///
    /// NOT deferred past a restore that is still draining, though
    /// a sequence queued behind another does lag the settle
    /// (#684's second half, still open). Holding it back and
    /// running it from the drain's completion was built and
    /// reverted: it re-raised windows whose echoes were still in
    /// flight, and the ledger then consumed a stamp on its FIRST
    /// echo, so the second echo read as a deliberate focus
    /// change (owner QA, 2026-08-02). #689 retired consumption
    /// (stamps expire by age), which removes that specific
    /// blocker — re-attempting the coalesce now needs its own
    /// red-proof, not this comment's permission.
    func scheduleZOrderRestore() {
        pendingZOrderRestore = true
        if tiler.animation.activeCount == 0 {
            runPendingZOrderRestore()
        }
    }

    /// Schedules a scrolling edge-pile restack after a swap, but
    /// only when the row overflows the viewport (#150): a fully
    /// visible row has no piles, so nothing overlaps and a swap
    /// scrambles no stacking. Call *after* the swap's retile, so
    /// the restore rides the new animations' settle rather than
    /// firing from the pre-swap frames (the #153 ordering rule).
    func scheduleScrollingZOrderRestoreIfOverflowing() {
        guard let input = tiler.layoutInput(state: state),
            input.space.mode == .scrolling,
            ScrollingLayout.rowOverflows(
                for: input.tiled,
                in: input.context
            )
        else { return }
        scheduleZOrderRestore()
    }

    /// Requests a z-order restore whose paired retile is the
    /// command dispatcher's own trailing `retile(force:)`, not
    /// one issued at the call site (#153). Recorded, not armed:
    /// `layoutCommand` fires `scheduleZOrderRestore` *after* that
    /// retile, so the restore can't run mid-retile off pre-retile
    /// frames and be consumed before the new animations begin.
    /// `promoteDemote` is the one such site (its reorder's retile
    /// belongs to the dispatcher).
    func requestZOrderRestoreAfterDispatch() {
        deferredCommandZOrderRestore = true
    }

    /// Runs a scheduled restore (called when animations end).
    func runPendingZOrderRestore() {
        guard pendingZOrderRestore else { return }
        pendingZOrderRestore = false
        guard let space = activeSpace else { return }
        switch space.mode {
        case .stack:
            restoreStackZOrder(space)
        case .scrolling:
            restoreScrollingZOrder(space)
        case .track:
            restoreTrackZOrder(space)
        case .monocle:
            restoreMonocleZOrder(space)
        default:
            break
        }
    }

    /// Monocle stacks every window at the same full-screen frame,
    /// so they all overlap and only the focused one shows. A plain
    /// focus change leans on the main-thread `AXHelper.raise`, which
    /// is unreliable across apps when KiwiDesk isn't frontmost (a
    /// non-activating App Bar click), so the clicked window can stay
    /// buried. Re-raise ONLY that one through the blocking ordered
    /// queue: raising the others too would churn focus window by
    /// window (AXRaise makes a same-app window key) and make the bar
    /// jump — and they overlap fully, so their order never shows
    /// (owner 2026-07-20).
    private func restoreMonocleZOrder(_ space: Space) {
        // A tiled-sticky traveler is the frontmost window but never
        // the membership-guarded `focused` slot (#431); raising
        // `space.focused` would bury it behind the space's own
        // local window. `focusAnchor` surfaces the traveler while
        // it holds the system focus. `thenFocus` gets the anchor
        // too: the closing re-assert fires only when it equals
        // `activeSpace.focused` (`raiseSequentially`), so a
        // traveler skips it and the raise stands, while a local
        // focus re-asserts as before.
        let tiled = state.effectiveTiledMembers(of: space)
        guard let focused = state.focusAnchor(of: space, tiled: tiled),
            state.windows[focused]?.isFloating == false
        else { return }
        // The floor is what makes this raise mean anything. Every
        // monocle window sits at the same full-screen frame, so
        // the one thing being asked for is "above the others" —
        // and with a lone target and no floor the plan is empty
        // by construction, since one window is trivially in order
        // among a set of one. That shipped: the restore ran and
        // raised nothing (architect review, 2026-08-02).
        raiseSequentially(
            [focused],
            thenFocus: focused,
            above: Self.raiseFloor(tiled: tiled, excluding: focused)
        )
    }

    /// Track (#193): an overflow cascade piles windows — the
    /// windows inside one track, or the merged overflow track —
    /// with the title-bar offset. Raise order follows the
    /// RENDERED cascade, not the array: `stickyExempt` (#414
    /// v2) can promote a piled sticky out of its array slot, so
    /// array order no longer equals cascade order; the frames
    /// themselves do (`cascadeRaiseOrder`), putting each pile's
    /// top window behind and its bottom in front, keeping every
    /// title bar visible.
    ///
    /// Raise ONLY the windows that actually overlap (#192): the
    /// side-by-side tracks that tile need no z-order, and raising
    /// them across apps only churns focus mid-sequence — a stray
    /// one can shuffle a pile member behind another and swallow
    /// its title bar. The focused window is re-raised last, the
    /// same override as the stack cascade.
    private func restoreTrackZOrder(_ space: Space) {
        guard let input = tiler.layoutInput(state: state) else {
            return
        }
        let frames = TrackLayout().calculateGeometry(
            for: input.tiled,
            in: input.context
        )
        // Any overlap = piled, matching the `framesCascade` gate
        // (raw intersection). Deliberately NOT `Navigation.
        // pileMates`' 25%-area threshold — that answers "worth
        // skipping in a swap", a different question. Tiled tracks
        // never overlap (inner gaps), so both agree in practice.
        let piled = input.tiled.filter { id in
            guard let rect = frames[id] else { return false }
            return input.tiled.contains { other in
                other != id
                    && !(frames[other]?
                        .intersection(rect).isEmpty ?? true)
            }
        }
        guard piled.count > 1 else { return }
        // The anchor, not `space.focused` (#431): with a focused
        // traveler the closing re-assert must skip (not steal
        // focus back to the stale local slot) — the monocle
        // restore's rule, applied to every restore.
        raiseSequentially(
            Self.cascadeRaiseOrder(piled, frames: frames),
            thenFocus: state.focusAnchor(
                of: space,
                tiled: input.tiled
            ),
            above: []
        )
    }

    /// Schedules a track z-order restore, but only when the
    /// layout actually cascades (the scrolling gate's twin,
    /// #150): tracks that tile side by side don't overlap, so a
    /// reorder scrambles no stacking and a needless re-raise
    /// would flicker focus. Call *after* the reorder's retile.
    func scheduleTrackZOrderRestoreIfOverflowing() {
        guard let input = tiler.layoutInput(state: state),
            input.space.mode == .track,
            Self.framesCascade(
                TrackLayout().calculateGeometry(
                    for: input.tiled,
                    in: input.context
                )
            )
        else { return }
        scheduleZOrderRestore()
    }

    /// Re-raises the stack zone top to bottom, so upper
    /// windows sit behind lower ones and every title bar of
    /// the cascade stays visible. A plain focus change still
    /// brings the focused window to the front, which is the
    /// expected override.
    private func restoreStackZOrder(_ space: Space) {
        // Per-space master boundary (#17), matching layout math.
        let boundary = max(
            1,
            tiler.settings.resolvedStack(for: space.id).masterCount
        )
        // The layout partitions the TILED list (#414 v2: sticky
        // travelers included at their injected index), so the
        // cascade to re-raise is its stack zone — raw
        // `space.windows` would misplace the boundary past any
        // floating member and miss travelers entirely.
        let tiled = state.effectiveTiledMembers(of: space)
        guard tiled.count > boundary else { return }
        // Frame-ordered, not array-ordered: the zone cascade's
        // rendered order can differ from the array once
        // `stickyExempt` promotes a piled sticky (#414 v2).
        // Anchor, not `space.focused` — see restoreTrackZOrder.
        raiseSequentially(
            Self.cascadeRaiseOrder(
                Array(tiled[boundary...]),
                frames: tiler.calculatedFrames(state: state)
            ),
            thenFocus: state.focusAnchor(of: space, tiled: tiled),
            above: []
        )
    }

    /// Scrolling: columns pushed past the screen edges are
    /// clamped there by macOS and pile up, overlapping. Each
    /// side must stack toward its own edge — the column
    /// nearest the focus on top, farther ones underneath —
    /// so the piles read as the row receding to the left and
    /// to the right of the viewport.
    private func restoreScrollingZOrder(_ space: Space) {
        let tiled = state.effectiveTiledMembers(of: space)
        guard tiled.count > 1 else { return }
        // Anchor, not `space.focused` — see restoreTrackZOrder.
        // The pile split follows the traveler's slot too: it is
        // the row position the viewport actually centers on.
        let anchor = state.focusAnchor(of: space, tiled: tiled)
        let focusIndex =
            anchor.flatMap {
                tiled.firstIndex(of: $0)
            } ?? 0
        raiseSequentially(
            Self.scrollingRaiseOrder(
                tiled,
                focusIndex: focusIndex
            ),
            thenFocus: anchor,
            above: []
        )
    }

    /// Raises the windows in exactly the given order, waiting for
    /// each raise to LAND before issuing the next.
    ///
    /// The wait is the whole point (#684): the AX call returns
    /// before a slow app has performed the raise, so a sequence
    /// issued back to back — which took ~10 ms for eight windows —
    /// leaves the apps to land them in whatever order they get to
    /// them, and the pile settles scrambled. `ZOrderDrain` owns
    /// the verification, the budget and the measurements.
    private func raiseSequentially(
        _ ids: [WindowID],
        thenFocus focused: WindowID?,
        above floor: [WindowID]
    ) {
        let pairs = ids.compactMap { id in
            eventLoop.element(for: id).map { (id, $0) }
        }
        guard !pairs.isEmpty else { return }
        // The raises below steal focus window by window (see the
        // queue comment) and their echoes carry no self-raise
        // provenance (#152/#425). Stamp the raised pile-mates (not
        // the focused window, re-asserted last) so their echoes are
        // reverted to the real focus instead of moving the ring onto
        // a pile member (`zOrderRaiseEchoes`, shared with the float
        // path); warps are held by that revert and by
        // `zOrderRestoresInFlight` (#186). The returned generation
        // guards the closing re-assert against a stale restore —
        // safe to also check live focus because the revert keeps
        // `activeSpace.focused` on the real target through the echoes.
        let generation = stampZOrderRaise(
            pairs.map(\.0),
            excluding: focused
        )
        performZOrderSequence(
            targets: pairs,
            above: floor,
            generation: generation
        ) {
            [weak self] in
            guard let self,
                generation == self.zOrderRaiseGeneration.value
            else { return }
            if let focused, focused == self.activeSpace?.focused {
                self.focusWindow(focused, warp: false)
            }
        }
    }
}
