import Accessibility
import AppKit
import Foundation

extension KiwiCore {
    /// Quiet-raises the windows that belong ABOVE the tiled
    /// plane: the active space's floating windows — their stash
    /// restore repositions but cannot re-order, so a focus raise
    /// buries them behind full-frame tiled windows — and every
    /// FLOATING sticky window (visible on all spaces, never
    /// stashed, equally buried). The target set gates on
    /// `isFloating`, never `isSticky` alone (#418 tier model): a
    /// tiled-sticky window is a real layout participant on the
    /// active space (#414 v2) and stays on the tiled plane —
    /// raising it would pop a tile over its neighbors.
    ///
    /// Then hands focus over as the sequence's ordered final step
    /// (the `raiseSequentially` pattern: AXRaise on a foreign
    /// window activates its app and steals focus window by window,
    /// so the intended focus must be re-asserted after the raises).
    /// The raised floats are recorded in `zOrderRaiseEchoes` so
    /// their focus echoes are reverted rather than moving the ring
    /// onto them (see `KiwiCore+Events`); the re-assert never warps
    /// — it runs while `zOrderRestoresInFlight` holds, where
    /// `mouseWarpEligible` swallows warps by design — so callers
    /// that want the pointer to follow warp at INTENT time, before
    /// calling this (as `focusSpace` does). With nothing to raise,
    /// focus is handed over directly.
    func raiseFloatsAndSticky(
        thenFocus focused: WindowID?
    ) {
        let pairs = floatLayerTargets().compactMap {
            id -> (WindowID, AXUIElement)? in
            eventLoop.element(for: id).map { (id, $0) }
        }
        guard !pairs.isEmpty else {
            if let focused {
                focusWindow(
                    focused,
                    refocusRetile: false,
                    warp: false
                )
            }
            return
        }
        // Stamp the floats so the focus echoes their AX raises emit
        // (AX couples raise with app activation) are reverted to the
        // real focus instead of moving the ring onto a float (#418);
        // the returned generation guards the handoff against a stale
        // sequence stealing focus back.
        let generation = stampZOrderRaise(
            pairs.map(\.0),
            excluding: focused
        )
        // What the floats must clear, and why the focused window
        // is not part of it, is argued on `raiseFloor`.
        let floor =
            activeSpace.map { space in
                Self.raiseFloor(
                    tiled: state.effectiveTiledMembers(
                        of: space,
                        activeSpace: space.id
                    ),
                    excluding: focused
                )
            } ?? []
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
                self.focusWindow(
                    focused,
                    refocusRetile: false,
                    warp: false
                )
            }
        }
    }

    /// Re-raises the float layer after focus lands on a tiled
    /// window, keeping floats above the just-focused window (#418).
    /// AX couples raise and focus, so the raised floats' apps
    /// activate; `raiseFloatsAndSticky` hands focus back and the
    /// float echoes are reverted (`zOrderRaiseEchoes`), so the
    /// ring stays on the focused tiled window while the floats keep
    /// their z-order above it. Gated by the caller to genuine
    /// (non-echo) focus changes so the focus-handoff's own echo
    /// cannot re-trigger the raise, and skipped when the focused
    /// window is itself a float (it is already on the float layer).
    ///
    /// Coalesced through the `.floatRaise` deferred slot: a burst of
    /// focus changes (rapid clicks, held focus-nav) would otherwise
    /// pile one full raise sequence per focus, and their intermediate
    /// raises thrash the z-order — more than one tile transiently
    /// ends up over the float. The slot self-cancels on reschedule,
    /// so only the window focus finally settles on raises the floats,
    /// leaving exactly the focused tile above them. The body re-reads
    /// `activeSpace?.focused` so a stale target no-ops.
    func raiseFloatsAbove(afterFocusing id: WindowID) {
        // Focusing a float returns without rescheduling, so a
        // `.floatRaise` still pending from a tile focus <50ms earlier
        // fires and no-ops (its id is stale) — a second float can then
        // sit under a tile until the next tiled focus re-raises the
        // layer. Self-healing and rare (sub-50ms tile→float); the
        // z-order thrash the coalescing removes is the worse failure.
        guard state.windows[id]?.isFloating != true,
            !floatLayerTargets().isEmpty
        else { return }
        deferred.schedule(.floatRaise, after: .milliseconds(50)) {
            [weak self] in
            guard let self, id == self.activeSpace?.focused
            else { return }
            self.raiseFloatsAndSticky(thenFocus: id)
        }
    }

    /// The ids of the windows that belong ABOVE the tiled plane:
    /// the active space's floating windows plus every floating
    /// sticky window (visible on all spaces, never stashed). The
    /// gate is `isFloating`, never `isSticky` alone — a tiled-sticky
    /// window is a real layout participant (#414 v2) and stays on
    /// the tiled plane. Sorted by id so overlapping floats keep a
    /// stable order across passes.
    ///
    /// **Known residue, mixed CGWindow layers (#684).** A float
    /// may sit at layer 0 (a normal window the user floated) or
    /// above it (`FloatDetection` floats a panel *because* its
    /// layer is non-zero). The compositor keeps a raised-layer
    /// window above every layer-0 one no matter what is raised, so
    /// whenever this array order asks for a layer-0 float in FRONT
    /// of a raised-layer one, that pairing cannot be reached: the
    /// sequence issues one raise that cannot verify and spends
    /// `ZOrderDrain.landingLimit` finding out. Bounded, once per
    /// float raise, and only in that mixed configuration — and the
    /// stacking is still correct, because the raised-layer float
    /// is above where the user needs it either way.
    ///
    /// Fixing it properly means ordering the desired sequence by
    /// layer, which needs the layer at this call site: it is NOT
    /// `isTransientOverlay` (that flag also covers layer-0
    /// dialogs, #300/#671), so it costs either a per-window
    /// WindowServer query here or a layer-carrying stacking read
    /// threaded into the drain. Deferred rather than guessed.
    func floatLayerTargets() -> [WindowID] {
        var targets: [WindowID] = []
        if let space = activeSpace {
            targets = space.windows.filter {
                state.windows[$0]?.isFloating == true
            }
        }
        for window in state.windows.all
            .sorted(by: { $0.id.raw < $1.id.raw })
        where window.isSticky && window.isFloating
            && !targets.contains(window.id)
        {
            targets.append(window.id)
        }
        return targets
    }

    /// Stamps `ids` (except `focused`, whose echo is the intended
    /// focus) into the shared z-order echo ledger and bumps the
    /// generation, returning it for the completion's staleness guard.
    /// One home for the prune window and the skip-focused rule,
    /// shared by the float raise and the pile restores (#418/#425) so
    /// the two paths cannot drift.
    func stampZOrderRaise(
        _ ids: [WindowID],
        excluding focused: WindowID?
    ) -> Int {
        let now = Date()
        zOrderRaiseEchoes = zOrderRaiseEchoes.filter {
            now.timeIntervalSince($0.value)
                < Self.zOrderRaiseEchoWindow
        }
        for id in ids where id != focused {
            zOrderRaiseEchoes[id] = now
        }
        return zOrderRaiseGeneration.bump()
    }

    /// Drops the raise stamps of the targets the drain did NOT
    /// raise, once it has finished.
    ///
    /// Once it has FINISHED, not once it has decided: the plan is
    /// settled by the drain's first read, but the result only
    /// comes back when the sequence ends, so an unraised window
    /// can still swallow a click for up to `ZOrderDrain
    /// .totalLimit`. Handing the plan back the moment it is
    /// computed would close that; it costs a second callback
    /// across the queue and the residue is bounded, so it is
    /// stated rather than denied (code review, 2026-08-02).
    ///
    /// A stamp is a promise that a raise echo is coming, and it is
    /// consumed by the first echo that arrives. Since the sequence
    /// started raising only what is out of place (#684), most of a
    /// pile is stamped and never raised — and nothing would ever
    /// consume those stamps, so for the next second a genuine
    /// CLICK on one of those windows was read as the echo and
    /// reverted: the click did nothing and the user had to click
    /// twice (owner QA, 2026-08-02). Keyboard focus was unaffected,
    /// which is the tell — it never emits the report this ledger
    /// inspects.
    ///
    /// Stamping is still the wide set rather than the plan,
    /// because the plan is decided on the raise queue after this
    /// runs, and a raise whose window was NOT stamped is the worse
    /// failure — its echo moves the ring onto a pile-mate.
    ///
    /// Guarded on the sequence's generation, like the focus
    /// handoff beside it: a drain that finishes after a NEWER
    /// sequence stamped the same windows would otherwise clear
    /// that sequence's fresh stamps, leaving its raises' echoes
    /// unabsorbed — which is the focus slide this branch already
    /// shipped once. The newer sequence owns the ledger; a stale
    /// drain releases nothing (architect review, 2026-08-02).
    func releaseZOrderStamps(
        of targets: [WindowID],
        keeping raised: [WindowID],
        generation: Int
    ) {
        guard generation == zOrderRaiseGeneration.value else {
            return
        }
        let awaited = Set(raised)
        for id in targets where !awaited.contains(id) {
            zOrderRaiseEchoes[id] = nil
        }
    }

    /// Runs a serial Z-order raise sequence on `zOrderQueue`,
    /// holding `zOrderRestoresInFlight` until the main-actor
    /// completion block finishes (#415 architect follow-up).
    ///
    /// Our OWN windows (the tracked Settings float) must be raised on
    /// the main thread: `AXUIElementPerformAction` on an own-process
    /// window runs AppKit's window ordering IN-PROCESS on the calling
    /// thread, so the background `zOrderQueue` trips AppKit's
    /// main-thread assertion and crashes (#426). Foreign raises are
    /// blocking IPC to another process's main thread and belong off
    /// our main thread. So own windows are raised here (this runs on
    /// the main actor), foreign ones on the queue.
    /// `generation` is the one the caller's `stampZOrderRaise`
    /// returned — passed in rather than re-read here, so the
    /// sequence has ONE identity: the drain's staleness check, the
    /// stamp release and the focus handoff all key on the same
    /// value. Re-reading it agreed only for as long as nothing ran
    /// between the stamp and this call (architect review,
    /// 2026-08-02).
    func performZOrderSequence(
        targets: [(WindowID, AXUIElement)],
        above floor: [WindowID],
        generation: Int,
        completion: @MainActor @escaping () -> Void
    ) {
        for (_, element) in targets
        where AXHelper.mustRaiseOnMainThread(element) {
            AXHelper.raiseQuietly(element)
        }
        let foreign = targets.filter {
            !AXHelper.mustRaiseOnMainThread($0.1)
        }
        // All-own (no foreign) runs the completion synchronously,
        // skipping the `zOrderRestoresInFlight` bracket. TWO
        // re-arm guards key on that counter — monocle's
        // (`KiwiCore+FocusRaise`) and scrolling's (#674) — so the
        // shortcut is what would let a restore's own closing
        // re-assert re-arm it. Monocle is safe because it is only
        // reached via a foreign focused window, so `foreign` is
        // never empty there. Scrolling does not read the counter
        // at all: its arm requires the focus to JUMP more than
        // one slot, and the closing re-assert targets the focus
        // that is already current, so the distance is zero — as
        // long as the re-asserted window is the one `focusAnchor`
        // then returns. Revisit the monocle half if an own window
        // can ever become a tiled restore member.
        guard !foreign.isEmpty else {
            completion()
            return
        }
        zOrderRestoresInFlight += 1
        let drain = zOrderDrain(
            over: foreign,
            above: floor,
            generation: generation
        )
        let order = foreign.map(\.0)
        zOrderQueue.async {
            let raised = drain.run(order)
            Task { @MainActor [weak self] in
                self?.releaseZOrderStamps(
                    of: order,
                    keeping: raised,
                    generation: generation
                )
                completion()
                self?.zOrderRestoresInFlight -= 1
            }
        }
    }

    /// The drain for one foreign raise sequence, with every
    /// machine effect bound to the real one (`ZOrderDrain` carries
    /// the argument, and the seams are what let it be tested
    /// without a WindowServer). The staleness seam reads the
    /// generation live, so a sequence superseded mid-drain
    /// abandons the raises it has left.
    private func zOrderDrain(
        over targets: [(WindowID, AXUIElement)],
        above floor: [WindowID],
        generation: Int
    ) -> ZOrderDrain {
        nonisolated(unsafe) let elements = Dictionary(
            targets,
            uniquingKeysWith: { first, _ in first }
        )
        let generations = zOrderRaiseGeneration
        return ZOrderDrain(
            raise: { id in
                elements[id].map(AXHelper.raiseQuietly)
            },
            stacking: { AXHelper.onScreenStackingOrder() },
            now: { ProcessInfo.processInfo.systemUptime },
            sleep: { Thread.sleep(forTimeInterval: $0) },
            isCurrent: { generations.value == generation },
            floor: floor
        )
    }
}
