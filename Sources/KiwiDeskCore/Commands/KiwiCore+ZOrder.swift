import AppKit
import Foundation

/// Serial queue for z-order raises. AX raise calls are
/// blocking IPC; running them here keeps the main thread free
/// and their order strict.
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
        let tiled = state.effectiveTiledMembers(
            of: space,
            activeSpace: activeSpace?.id
        )
        guard let focused = state.focusAnchor(of: space, tiled: tiled),
            state.windows[focused]?.isFloating == false
        else { return }
        raiseSequentially([focused], thenFocus: focused)
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
            )
        )
    }

    /// Raise order for a cascading region: ascending `minY` —
    /// piles always cascade downward, so the most-buried
    /// (topmost) frame raises first and each later raise lands
    /// on top of it. Frame order, not array order: the render
    /// can reorder a pile (`OverlapStack.stickyExempt`, #414
    /// v2), and raising in array order would bury the displaced
    /// window's title bar under the promoted sticky's full
    /// slot. Non-overlapping members sort in too (harmless —
    /// nothing they cover). Ties keep the input order. Pure
    /// math, unit-tested.
    nonisolated static func cascadeRaiseOrder(
        _ ids: [WindowID],
        frames: [WindowID: CGRect]
    ) -> [WindowID] {
        // A frameless id raises LAST (on top): unreachable
        // today (both callers derive ids and frames from the
        // same layout), but if a derivation ever drifts, a
        // window floating above the cascade is visible —
        // buried under it would be a silent loss.
        let unknown = CGFloat.greatestFiniteMagnitude
        return
            ids.enumerated()
            .sorted { a, b in
                let ya = frames[a.element]?.minY ?? unknown
                let yb = frames[b.element]?.minY ?? unknown
                if ya != yb { return ya < yb }
                return a.offset < b.offset
            }
            .map(\.element)
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

    /// Whether any two laid-out frames overlap — the signature
    /// of an overflow cascade. Tiled tracks never overlap (the
    /// inner gaps separate them), so this is false whenever the
    /// space fits without piling. Pure math, unit-tested.
    nonisolated static func framesCascade(
        _ frames: [WindowID: CGRect]
    ) -> Bool {
        let rects = Array(frames.values)
        for i in rects.indices {
            for j in (i + 1)..<rects.count
            where !rects[i].intersection(rects[j]).isEmpty {
                return true
            }
        }
        return false
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
        let tiled = state.effectiveTiledMembers(
            of: space,
            activeSpace: activeSpace?.id
        )
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
            thenFocus: state.focusAnchor(of: space, tiled: tiled)
        )
    }

    /// Scrolling: columns pushed past the screen edges are
    /// clamped there by macOS and pile up, overlapping. Each
    /// side must stack toward its own edge — the column
    /// nearest the focus on top, farther ones underneath —
    /// so the piles read as the row receding to the left and
    /// to the right of the viewport.
    private func restoreScrollingZOrder(_ space: Space) {
        let tiled = state.effectiveTiledMembers(
            of: space,
            activeSpace: activeSpace?.id
        )
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
            thenFocus: anchor
        )
    }

    /// The raise sequence for the scrolling piles: both sides
    /// run farthest-from-focus first, so every raise lands on
    /// top of the previous one — the left pile ascending, the
    /// right pile descending. The focused window itself is
    /// left out; the closing focus re-assert puts it on top.
    /// Pure math, unit-tested.
    nonisolated static func scrollingRaiseOrder(
        _ windows: [WindowID],
        focusIndex: Int
    ) -> [WindowID] {
        guard windows.indices.contains(focusIndex) else {
            return windows
        }
        return Array(windows[..<focusIndex])
            + windows[(focusIndex + 1)...].reversed()
    }

    /// Raises the windows in exactly the given order. Raises
    /// run sequentially on one queue: each call returns only
    /// after the target app processed it, which keeps the
    /// order across apps.
    private func raiseSequentially(
        _ ids: [WindowID],
        thenFocus focused: WindowID?
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
        performZOrderSequence(elements: pairs.map(\.1)) {
            [weak self] in
            guard let self,
                generation == self.zOrderRaiseGeneration
            else { return }
            if let focused, focused == self.activeSpace?.focused {
                self.focusWindow(focused, warp: false)
            }
        }
    }
}
