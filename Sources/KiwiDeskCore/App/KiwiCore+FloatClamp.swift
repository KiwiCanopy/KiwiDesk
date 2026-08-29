import CoreGraphics

/// Keeps floating windows clear of every painted bar. Floats
/// are excluded from all layout geometry
/// (`TilingEngine.layoutInput` filters them out), so nothing
/// otherwise stops one from sliding under a strip. The original
/// motivator was a TOP bar covering the title bar and leaving
/// the float ungrabbable (#242); since QA 2026-07-19 all four
/// edges nudge — a bar reserves its edge for every window kind,
/// the way the Dock reserves `visibleFrame`, and a top-only
/// nudge read as an inconsistency, not a scoped decision.
///
/// Strips are read from the bars the managers actually painted
/// (`shownStrips`), never re-derived here: a second derivation
/// drifts from what is on screen — outer gaps, the empty-bar
/// suppression, per-display screen pick — and each drift is a
/// way the float ends up wrongly placed or moved for no visible
/// bar.
extension KiwiCore {
    /// `frame` nudged clear of every bar painted for the
    /// window's own space, or returned unchanged when that
    /// space shows none. Callers with a fresher read than state
    /// (a fresh drop, a resize target) pass their own frame in.
    func floatFrameClampedClearOfBars(
        _ id: WindowID,
        frame: CGRect
    ) -> CGRect {
        guard let space = state.workspaces.space(of: id)
        else { return frame }
        var result = frame
        let inset = floatRingInset
        // Order is immaterial: each clamp is a monotonic push
        // off its edge, so on a shared edge the deeper strip's
        // push subsumes the shallower one's either way.
        for (strip, edge) in paintedStrips(forSpace: space) {
            result = AppBarGeometry.clampClear(
                result,
                of: strip,
                edge: edge,
                inset: inset
            )
        }
        return result
    }

    /// The region a float may occupy on its own space: the
    /// screen's visible bounds with every painted bar strip
    /// carved off its edge (#1091). Nil where the space resolves
    /// to no screen, which callers read as unbounded.
    ///
    /// **The one derivation of the region.** It bounds nothing
    /// by itself — each consumer decides what it enforces, and
    /// says so at its own site: the resize math takes the whole
    /// rect because pinning is a question about how much room
    /// each EDGE has, the retile fit bounds a float's size to
    /// it, and `floatFrameClampedClearOfBars` above deliberately
    /// keeps pushing off bar edges alone. That last one is the
    /// scope worth stating twice: it runs for every float on
    /// every retile, so enforcing the screen edge there would
    /// drag back a window the user parked half off-screen by
    /// hand, which macOS allows and this issue never asked for.
    ///
    /// Bars vary per space — one bar or two, on any edge — so
    /// this folds both strip lists exactly as the clamp does
    /// rather than assuming a count or an edge. Two strips on
    /// ONE edge leave the deeper carve standing, which is the
    /// monotonicity `AppBarGeometry.regionClear` provides and
    /// the reason the fold needs no ordering rule.
    ///
    /// Reads the display through `TilingEngine.visibleBounds`
    /// (#531), never `GeometryUtils.axVisibleFrame` — a direct
    /// call reds `VisibleBoundsRoutingTests`.
    func floatBounds(of id: WindowID) -> CGRect? {
        guard let space = state.workspaces.space(of: id),
            let screen = TilingEngine.screen(
                for: space,
                in: state
            )
        else { return nil }
        var region = tiler.visibleBounds(screen)
        for (strip, edge) in paintedStrips(forSpace: space) {
            region = AppBarGeometry.regionClear(
                region,
                of: strip,
                edge: edge,
                inset: floatRingInset
            )
        }
        return region
    }

    /// How far clear of a bar a float is kept so its focus RING
    /// clears it too, not only the window (#1091): the
    /// configured ring width, or zero with rings off.
    ///
    /// Read from the configured style rather than a window's own
    /// spec, and applied to every float regardless of focus. An
    /// inset that tracked the ring's actual presence would shift
    /// a float a few points each time it gained or lost focus —
    /// which is worse than the sliver it would recover.
    // Internal rather than private so the guard can read it:
    // the strips it feeds are only reachable through a painted
    // bar, so a test that went the long way round would be
    // guarding `AppBarManager.sync` instead of this rule.
    var floatRingInset: CGFloat {
        let style = tiler.settings.borderStyle
        guard style.enabled else { return 0 }
        // `BorderGeometry.outwardReach` is the named authority
        // for how far the stroke reaches PAST the window edge,
        // and `BorderStyle.fittingGaps` already routes through
        // it. `clampedWidth` equals it today and stops the day
        // reach and stroke diverge — which is exactly the
        // "ring reads as cut off" defect this inset removes
        // (architect + code review, 2026-08-29).
        return BorderGeometry.outwardReach(width: style.width)
    }

    /// EVERY painted strip covering `space` — both bars, in one
    /// list. One accessor rather than the `spaceBarStrips +
    /// appBars.strips` expression repeated per consumer: a
    /// space shows one bar or two on any edge, and a third bar
    /// source must reach every site that asks "what chrome
    /// covers this space" (architect review, 2026-08-29).
    private func paintedStrips(
        forSpace space: SpaceID
    ) -> [(strip: CGRect, edge: AppBarEdge)] {
        spaceBarStrips(forSpace: space)
            + appBars.strips(forSpace: space)
    }

    /// The painted Space Bar strips covering `space`. The
    /// Space Bar is per-display; a space is covered by the
    /// bar of the display currently showing it.
    private func spaceBarStrips(
        forSpace space: SpaceID
    ) -> [(strip: CGRect, edge: AppBarEdge)] {
        spaceBars.shownStrips
            .filter { display, _, _ in
                state.workspaces.currentSpace(on: display)
                    == space
            }
            .map { (strip: $0.strip, edge: $0.edge) }
    }

    /// The clamp above, plus a SIZE fit into `floatBounds`
    /// (#1091). The clamp only ever moves — `clampClear` writes
    /// `origin` and never `size` — so a float larger than the
    /// space between the bars is pushed to one side and still
    /// overflows under the other, which is how a window grown
    /// before this rule (or sized by its own app) ends up
    /// unusable beneath a bar.
    ///
    /// Only the SIZE is bounded here. Position stays the user's:
    /// this runs for every float on every retile, so enforcing
    /// the screen edge as well would drag back a window parked
    /// half off-screen by hand, which macOS allows and nobody
    /// asked for.
    ///
    /// Scoped to spaces that actually SHOW a bar, because that
    /// is where the harm is — a float merely larger than the
    /// screen is the user's business, and only a bar makes part
    /// of a window unreachable. `clampFloatsClearOfBars` already
    /// iterates exactly those spaces.
    ///
    /// The fit is tolerance-gated for the reason the clamp is:
    /// re-applying a sub-point correction every retile would
    /// wobble the window.
    func floatFrameFittedClearOfBars(
        _ id: WindowID,
        frame: CGRect
    ) -> CGRect {
        var result = frame
        if let region = floatBounds(of: id) {
            let slack = AppBarGeometry.clampTolerance
            // Floored at the window's effective minimum, and the
            // FLOOR wins the contradiction (code review,
            // 2026-08-29): bars have a lower thickness clamp and
            // no upper one, so a deep enough bar leaves a region
            // narrower than `min_window_size` — or, at the
            // limit, a zero-extent one, which AppKit rejects
            // outright. Leave such a window oversized rather
            // than write a frame it cannot have. Scrolling rules
            // the same clash the same way.
            let floorW = CGFloat(
                effectiveMinSize(of: id, axis: "x")
            )
            let floorH = CGFloat(
                effectiveMinSize(of: id, axis: "y")
            )
            if result.width > region.width + slack {
                result.size.width = max(
                    region.width,
                    min(floorW, result.width)
                )
            }
            if result.height > region.height + slack {
                result.size.height = max(
                    region.height,
                    min(floorH, result.height)
                )
            }
        }
        return floatFrameClampedClearOfBars(id, frame: result)
    }

    /// Whether the retile sweep should issue `fitted`, and the
    /// only place the refusal memo is consulted and updated.
    ///
    /// A SIZE ask can be refused where a position ask is not,
    /// and this sweep runs on every retile — so without a memo
    /// an app whose minimum exceeds the region is re-asked
    /// forever, having already refused (code review,
    /// 2026-08-29). #677's shape one subsystem over: learn the
    /// refusal from our own ask and stop re-issuing.
    ///
    /// A position-only correction is exempt and always issues:
    /// a move is nearly always accepted, so it converges without
    /// a memo — which is exactly why the clamp this sits beside
    /// never needed one.
    ///
    /// Split out of the sweep so the DECISION is reachable
    /// without a painted bar (guard-prover, 2026-08-29):
    /// `FloatFitLedgerTests` guards the ledger's own algebra and
    /// structurally cannot see its consumer, and deleting this
    /// consultation left all 4259 tests green.
    func shouldIssueFloatFit(
        _ id: WindowID,
        current: CGRect,
        fitted: CGRect
    ) -> Bool {
        guard fitted.size != current.size else { return true }
        guard
            !tiler.floatFitLedger.repeatsRefusal(
                id,
                asked: fitted.size,
                seen: current.size
            )
        else { return false }
        tiler.floatFitLedger.record(
            id,
            asked: fitted.size,
            seen: current.size
        )
        return true
    }

    /// Re-asserts the bar clamp for every floating window under
    /// a painted bar, across all displays. The structural
    /// safety net, run from `retile()` after the bars are
    /// synced: a window turned floating under an existing bar,
    /// or a bar switched on over an existing float, is
    /// corrected here. Drag and resize clamp their own fresh
    /// frame directly.
    func clampFloatsClearOfBars() {
        for space in spacesWithShownBars {
            guard let windows = state.workspaces[space]?.windows
            else { continue }
            for id in windows {
                guard let window = state.windows[id],
                    window.isFloating
                else { continue }
                // One fold over every strip, one apply: the
                // per-strip loop this replaces re-read the same
                // stale state frame for each strip (applyFrame
                // is async), so with stacked bars the second
                // clamp overwrote the first instead of
                // composing with it.
                let clamped = floatFrameFittedClearOfBars(
                    id,
                    frame: window.frame
                )
                guard clamped != window.frame else {
                    // Nothing to correct: drop any refusal memo
                    // so a window that later needs a fit is
                    // asked afresh.
                    tiler.floatFitLedger.forget(id)
                    continue
                }
                guard
                    shouldIssueFloatFit(
                        id,
                        current: window.frame,
                        fitted: clamped
                    )
                else { continue }
                tiler.applyFrame(
                    id,
                    from: window.frame,
                    to: clamped,
                    animated: false
                )
            }
        }
    }

    /// Every space with at least one painted strip: the App
    /// Bars' own spaces, plus the space each Space-Bar-covered
    /// display is showing (#293: per-display bar, occludes the
    /// current space).
    private var spacesWithShownBars: Set<SpaceID> {
        var spaces = Set(appBars.shownStrips.map(\.space))
        for (display, _, _) in spaceBars.shownStrips {
            guard
                let space =
                    state.workspaces.currentSpace(on: display)
            else { continue }
            spaces.insert(space)
        }
        return spaces
    }
}
