import CoreGraphics
import Foundation

// MARK: - App-enforced size bounds (#677)

/// The engine's half of the size-bound machinery: how `retile`
/// consults the learner, and the invalidation surface the event
/// flow calls. The learning ladder itself is `SizeBoundLearner`;
/// what a learned bound means is `EffectiveSizeBound`.
extension TilingEngine {
    /// The #677 channels' shared "is this our own ask's echo"
    /// probe: production reads the applier's recent-set stamp;
    /// fixtures with a severed applier inject through
    /// `echoGraceOverride`, because the stamp is only written
    /// by a real AX apply.
    func askEchoLikely(_ id: WindowID) -> Bool {
        echoGraceOverride?(id) ?? didRecentlySetFrame(id)
    }

    /// The retile-time observe gate (#677): a settled window's
    /// echo-fed frame is the app's answer to the engine's last
    /// ask. Neither a mid-flight frame (travel, not an answer)
    /// nor one inside its ask's echo grace counts — two rapid
    /// retiles re-asking one target before any echo lands
    /// would otherwise read the stale pre-ask frame as the
    /// same refusal twice and confirm a false bound (review,
    /// 2026-08-18). Deferring costs nothing but time: the echo
    /// channel below is the primary learner now, and this pass
    /// only mops up answers whose echoes were missed.
    /// Returns whether the gate passed — i.e. `current` is an
    /// echo-quiet, settled reading. The retile loop threads
    /// that verdict into `recordAsk(settledFrom:)` so a quiet
    /// issue's pre-ask size can serve as the first observation
    /// (`SizeBoundLearner.Ask`).
    @discardableResult
    func observeAppAnswer(
        for id: WindowID,
        current: CGRect
    ) -> Bool {
        guard !animation.isAnimating(window: id),
            !askEchoLikely(id)
        else { return false }
        if boundLearner.observe(
            id,
            currentSize: current.size,
            settledRead: true
        ) {
            pendingBoundPlacement = true
        }
        return true
    }

    /// The echo-time observation (#677, device QA 2026-08-18):
    /// an echo of our own set IS the app's answer, knowable the
    /// moment it arrives — the retile-time pass alone starved,
    /// because every unconfirmed retile re-issued the ask and
    /// restarted the very grace the observation waited on, and
    /// a quiet screen produced no retile to learn from at all.
    /// Gated on the animation being done: an in-flight echo is
    /// travel, and the spring's deceleration tail can emit two
    /// near-identical sizes shy of the target — a false confirm
    /// the settled gate closes. Returns the confirmation edge;
    /// the caller answers it with an immediate retile so the
    /// residue (re-pack / centering) is placed right then.
    ///
    /// `settledRead` threads the #1049 distinction: the settle
    /// probe reads past the app's chance to revert (true), a
    /// raw move/resize echo does not (false) — and only a
    /// settled compliance may clear learning, or the Android
    /// emulator's comply-then-snap-back wipes the ladder every
    /// cycle. The argument lives on `SizeBoundLearner.observe`.
    func observeEchoAnswer(
        _ id: WindowID,
        size: CGSize,
        settledRead: Bool
    ) -> Bool {
        guard !animation.isAnimating(window: id)
        else { return false }
        return boundLearner.observe(
            id,
            currentSize: size,
            settledRead: settledRead
        )
    }

    /// The settle probe's gate — see
    /// `SizeBoundLearner.wantsProbe`.
    func wantsAnswerProbe(
        _ id: WindowID,
        currentSize: CGSize
    ) -> Bool {
        boundLearner.wantsProbe(id, currentSize: currentSize)
    }

    /// The candidate view, for the probe's seeded-vs-updated
    /// distinction — see `SizeBoundLearner.candidateBound`.
    func candidateSizeBound(
        for id: WindowID
    ) -> EffectiveSizeBound? {
        boundLearner.candidateBound(for: id)
    }

    /// Consumes the retile-channel confirmation flag (#677):
    /// the retile loop cannot retile itself, so
    /// `KiwiCore.retile` reads this after the pass and runs the
    /// placement immediately instead of leaving the residue for
    /// the next unrelated event.
    func takePendingBoundPlacement() -> Bool {
        defer { pendingBoundPlacement = false }
        return pendingBoundPlacement
    }

    /// Whether a reported size is one the ledger already
    /// explains — the forget gate's second term: a late echo of
    /// our own ask (past the applier's grace, or delayed by the
    /// #618 read queue) must not classify as a genuine resize
    /// and wipe the learning it is evidence FOR.
    func ledgerExplainsResize(
        _ id: WindowID,
        size: CGSize
    ) -> Bool {
        boundLearner.explainsResize(id, size: size)
    }

    /// Whether a retile target that fails the plain skip check
    /// is nevertheless "already there": the window's position
    /// matches, and every size axis off target is re-asking an
    /// ask the app has twice refused — or asking beyond a
    /// corroborated bound (#1055) — with the window at the
    /// learned answer. Consulted un-forced only — an explicit
    /// apply keeps its contract of re-issuing everything, and
    /// since #1055 its forced pass also probes past
    /// corroborated bounds (`LayoutContext.probesBeyondBounds`).
    func sizeBoundExplains(
        _ id: WindowID,
        current: CGRect,
        target: CGRect
    ) -> Bool {
        guard
            abs(current.minX - target.minX)
                <= Self.retileTolerance,
            abs(current.minY - target.minY)
                <= Self.retileTolerance,
            let bound = boundLearner.bound(for: id)
        else { return false }
        return bound.explains(
            currentSize: current.size,
            targetSize: target.size
        )
    }

    /// The confirmed bound for one window, nil while unproven.
    /// Read by the layout-context threading (`layoutInput`) and
    /// the overlay pin below.
    func sizeBound(for id: WindowID) -> EffectiveSizeBound? {
        boundLearner.bound(for: id)
    }

    /// Every confirmed bound for the given windows — the
    /// layout-context input (#677): a layout may consume a
    /// bound as the window's own span (scrolling re-packs the
    /// row, monocle centers) so the residue the refusal leaves
    /// is placed deliberately instead of piling at the slot
    /// origin.
    func sizeBounds(
        for windows: [WindowID]
    ) -> [WindowID: EffectiveSizeBound] {
        var result: [WindowID: EffectiveSizeBound] = [:]
        for id in windows {
            if let bound = boundLearner.bound(for: id) {
                result[id] = bound
            }
        }
        return result
    }

    /// The per-axis pin for a window OUR animation is driving
    /// toward a size the app has already refused (#677): the
    /// learned answer where the in-flight target re-asks the
    /// refused ask, nil otherwise — including nil while no
    /// animation is in flight, because only the tick channel
    /// consumes it. The follow tee threads this into
    /// `FollowSource.renderFrame`, which is where the decision
    /// lives.
    ///
    /// Falls back to the UNCONFIRMED candidate where no
    /// confirmed entry answers (#677 device QA): a render is
    /// cosmetic and self-corrects at settle, so the ring may
    /// trust a single refusal — the visible ride-out then
    /// happens once, on the first encounter, instead of on
    /// every probe. Geometry never takes this fallback
    /// (`sizeBounds(for:)` above is confirmed-only).
    func animationSizePin(
        for id: WindowID
    ) -> SizePin? {
        guard let target = animation.targetFrame(window: id)
        else { return nil }
        let confirmed = boundLearner.bound(for: id)
        let candidate = boundLearner.candidateBound(for: id)
        let pin = SizePin(
            width: confirmed?
                .consumedWidth(asking: target.width)
                ?? candidate?
                .consumedWidth(asking: target.width),
            height: confirmed?
                .consumedHeight(asking: target.height)
                ?? candidate?
                .consumedHeight(asking: target.height)
        )
        return pin.isEmpty ? nil : pin
    }

    /// Drops everything learned about a window on a genuine
    /// (non-echo) resize — the user or the app itself changed
    /// the size, so the ledger is stale. The GONE paths take
    /// `stashSizeBoundOnGone` instead.
    public func forgetSizeBound(_ id: WindowID) {
        boundLearner.forget(id)
    }

    /// The gone-window forget (#152/#158), parking the believed
    /// ledger for a possible flap re-add (#1049) — see
    /// `SizeBoundLearner.stashOnGone`.
    public func stashSizeBoundOnGone(
        _ id: WindowID,
        pid: pid_t
    ) {
        boundLearner.stashOnGone(id, pid: pid, now: Date())
    }

    /// Restores a parked ledger for a re-added window — same
    /// id, same pid, within the grace (#1049). Called from the
    /// `.windowCreated` arm before the arrival retile, so the
    /// re-add tiles straight to the learned answer.
    @discardableResult
    public func reviveSizeBound(
        _ id: WindowID,
        pid: pid_t
    ) -> Bool {
        boundLearner.revive(id, pid: pid, now: Date())
    }

    /// Migrates the ledger across a native-tab rekey (#308),
    /// beside `rekeyStash`: same on-screen window, new id.
    public func rekeySizeBound(
        oldID: WindowID,
        newID: WindowID
    ) {
        boundLearner.rekey(old: oldID, new: newID)
    }
}
