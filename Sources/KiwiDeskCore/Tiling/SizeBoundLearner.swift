import CoreGraphics
import Foundation

/// Learns app-enforced size bounds from the engine's own asks
/// (#677). `retile` records every size it issues
/// (`recordAsk`); at a later retile, once the window's
/// animation is done, the echo-fed state frame is the app's
/// answer to that ask (`observe`). The same ask refused with
/// the same answer **twice in a row** confirms an
/// `EffectiveSizeBound` for that axis; an ask the app complies
/// with clears the axis — candidate and any stale confirmed
/// bound its answer contradicts — so a lifted constraint heals
/// the moment the engine happens to ask past it again.
///
/// The engine gates `observe` on the window not animating AND
/// on its last set's echo grace having passed
/// (`TilingEngine.observeAppAnswer`): a pending echo makes
/// the stale pre-ask frame a *deterministic* repeated answer,
/// which two rapid retiles would confirm as a false bound —
/// so an ask inside its echo grace is not observed yet. The
/// grace is a time bound, not echo receipt, which is the first
/// accepted imprecision below.
///
/// Four accepted imprecisions, weighed rather than overlooked:
/// an app whose echo outlasts the grace (the stalled-app
/// class — its echo event also rides the #618 read queue) can
/// still present the stale pre-ask frame as a repeated answer
/// and confirm a false bound, narrowed by the grace and healed
/// by the same compliance and invalidation arms as every other
/// stale entry. A cancel mid-flight can seed one wrong
/// candidate (the frame observed is mid-travel, not an
/// answer); the next SAME-ASK observation overwrites it, and
/// one for an ask that never recurs persists until eviction or
/// forget — where its one consumer, the overlay pin, can
/// mis-render a single matching flight before the settle keys
/// re-read reality. A constraint
/// that lifts with no resize event and no recurring ask stays
/// learned until an invalidation fires; the forget on every
/// genuine (non-echo) resize covers the real-world case, an
/// app re-bounding itself (System Settings switching panes).
/// And the comply-then-revoke pair-promote (#1049) trusts the
/// FIRST off-ask echo after a same-ask compliance as the
/// definitive answer — an app that ANIMATES its revoke rather
/// than snapping hands it a mid-travel frame, a believed-tier
/// twin of the cancel-mid-flight seed above; the next two
/// same-ask observations overwrite it through the ordinary
/// ladder, and the shape is bounded the same way.
///
/// Pure bookkeeping — no AX, no actors — so the confirm ladder
/// is unit-testable (`SizeBoundLearnerTests`).
struct SizeBoundLearner {
    /// Per-window, per-axis entry lists — the same shape twice,
    /// once for unconfirmed candidates and once for believed
    /// bounds. Entries are keyed by their asked span (matched
    /// within the quantum) and capped per axis, oldest evicted:
    /// different layouts ask different sizes, and a single slot
    /// per axis let them overwrite each other's ladder so the
    /// less-visited layout never converged (device QA,
    /// 2026-08-18).
    // Internal (not private): the invalidation half lives in
    // `SizeBoundLearner+Invalidation.swift`, split at the file
    // ceiling, and Swift private does not cross files.
    struct Ledger {
        var width: [EffectiveSizeBound.Axis] = []
        var height: [EffectiveSizeBound.Axis] = []
        var isEmpty: Bool { width.isEmpty && height.isEmpty }
    }

    /// Distinct asks remembered per axis. Sized WELL past the
    /// real producers — one ask per layout mode a window meets,
    /// and a window rarely tiles under more than three or
    /// four — because eviction is only a leak bound: evicting a
    /// candidate before its confirming re-encounter re-opens
    /// the starvation the per-ask shape exists to close
    /// (review, 2026-08-18), so the cap must never bind in
    /// ordinary use. Recurring past it costs a re-probe, not
    /// correctness.
    static let maxEntriesPerAxis = 8

    /// One recorded ask: the size issued, and — when the issue
    /// happened from an echo-quiet, settled state — the size the
    /// window held at that moment. The baseline is a real
    /// observation: "held X before the ask, still exactly X
    /// after a whole animation of size-sets" IS the same answer
    /// twice, which is what lets the common case confirm from a
    /// single post-settle probe (~the probe grace after the
    /// dance settles) instead of a second full cycle (device
    /// QA, 2026-08-18: "could we make it immediate?").
    ///
    /// The `echoComplied*` flags carry the OTHER single-cycle
    /// shortcut (#1049): an echo-channel compliance for this
    /// ask's axis. They exist so a comply-then-revoke pair can
    /// promote directly — see `observeAxis`. Reset by
    /// `recordAsk`, since a new ask is a new question.
    struct Ask {
        var size: CGSize
        var settledFrom: CGSize?
        var echoCompliedWidth = false
        var echoCompliedHeight = false
    }

    /// The parked ledgers of gone windows (#1049): a slow AX
    /// app (the Android emulator, ~700 ms reconciles) flaps —
    /// its window is briefly dropped and re-added under the
    /// SAME id — and the destroy-forgets rule (#152/#158) made
    /// every re-add re-run the whole learn dance on screen.
    /// The revive half, its pid check and the grace live in
    /// `SizeBoundLearner+Invalidation.swift`.
    struct Tombstone {
        var bounds: Ledger
        var pid: pid_t
        var at: Date
    }

    var lastAsks: [WindowID: Ask] = [:]
    var candidates: [WindowID: Ledger] = [:]
    var bounds: [WindowID: Ledger] = [:]
    var tombstones: [WindowID: Tombstone] = [:]

    /// The size `retile` just issued for a window. Only the
    /// layout loop records — a stash park or float restore is
    /// not a layout ask, and learning from one would key a
    /// bound to a frame no layout will re-issue.
    /// The size `retile` just issued for a window. Only the
    /// layout loop records — a stash park or float restore is
    /// not a layout ask, and learning from one would key a
    /// bound to a frame no layout will re-issue. `settledFrom`
    /// carries the window's size at issue time ONLY when the
    /// issue happened from an echo-quiet, settled state — an
    /// untrusted baseline (mid-flight, echo pending) must stay
    /// nil, or a stale frame fakes the second observation.
    mutating func recordAsk(
        _ id: WindowID,
        size: CGSize,
        settledFrom: CGSize? = nil
    ) {
        lastAsks[id] = Ask(size: size, settledFrom: settledFrom)
    }

    /// The app's answer to the last recorded ask: the window's
    /// settled, echo-fed frame size. Callers gate on the
    /// window not animating — a mid-flight frame is travel,
    /// not an answer. Returns whether a BELIEVED entry was
    /// created or changed — the confirmation edge the caller
    /// answers with an immediate retile, so the residue is
    /// placed the moment the bound is known instead of at the
    /// next unrelated event (device QA, 2026-08-18: the
    /// re-pack "taking many visits" was this placement waiting
    /// for a retile that had no reason to come).
    ///
    /// `settledRead` says whether this reading is past the
    /// app's chance to revert it — the retile-time gate and the
    /// settle probe are; a raw echo is not. Only a settled
    /// compliance runs the `complied` sweep (#1049): the
    /// Android emulator ANIMATES to the full asked size, holds
    /// it ~0.4 s, then snaps back to its aspect ratio — and the
    /// transient compliance echo cleared the candidate every
    /// cycle, so "twice in a row" never accumulated and the
    /// probe retile re-issued the dance forever. An echo-channel
    /// compliance now learns nothing and clears nothing; the
    /// constraint-lifted heal still runs, one settled read
    /// later (every retile makes one, before its skip check).
    @discardableResult
    mutating func observe(
        _ id: WindowID,
        currentSize: CGSize,
        settledRead: Bool
    ) -> Bool {
        guard let ask = lastAsks[id] else { return false }
        let asked = ask.size
        // A non-positive span cannot be a real on-screen
        // window — it is a state frame no echo ever wrote (a
        // window created and never heard from again), not an
        // answer. Learning it would confirm a 0 pt "bound" and
        // collapse the slot.
        guard currentSize.width > 0, currentSize.height > 0
        else { return false }
        let widthConfirmed = observeAxis(
            id,
            asked: asked.width,
            current: currentSize.width,
            baseline: ask.settledFrom?.width,
            settledRead: settledRead,
            axis: \.width,
            echoComplied: \.echoCompliedWidth
        )
        let heightConfirmed = observeAxis(
            id,
            asked: asked.height,
            current: currentSize.height,
            baseline: ask.settledFrom?.height,
            settledRead: settledRead,
            axis: \.height,
            echoComplied: \.echoCompliedHeight
        )
        return widthConfirmed || heightConfirmed
    }

    /// Promotes a candidate to a believed bound, returning
    /// whether the believed ledger actually CHANGED —
    /// re-promoting an identical entry is not a confirmation
    /// edge, which is what keeps the caller's answer (an
    /// immediate retile) from looping on its own echoes.
    ///
    /// Internal rather than private since #1083 split the
    /// observation ladder into `SizeBoundLearner+Observe`;
    /// still module-internal, and no caller outside the two
    /// learner files may reach it.
    mutating func promote(
        _ id: WindowID,
        asked: CGFloat,
        answered: CGFloat,
        axis: WritableKeyPath<Ledger, [EffectiveSizeBound.Axis]>
    ) -> Bool {
        var entries = bounds[id]?[keyPath: axis] ?? []
        let entry = EffectiveSizeBound.Axis(
            asked: asked,
            answered: answered
        )
        if let index = entries.firstIndex(where: {
            EffectiveSizeBound.matches($0.asked, asked)
        }) {
            if EffectiveSizeBound.matches(
                entries[index].answered,
                answered
            ) {
                return false
            }
            entries[index] = entry
        } else {
            entries.append(entry)
            if entries.count > Self.maxEntriesPerAxis {
                entries.removeFirst()
            }
        }
        writeBounds(id, entries: entries, axis: axis)
        return true
    }

}
