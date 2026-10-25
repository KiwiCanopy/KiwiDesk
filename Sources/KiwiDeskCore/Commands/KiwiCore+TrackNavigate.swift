import AppKit
import Foundation

/// Track-mode navigation (#128): array-order focus/swap stepping
/// and `move_to_track`, split out of `KiwiCore+NavigateCommand`
/// for file size. Array order IS spatial order inside a track
/// (and track order across them), so stepping is index math —
/// the scrolling precedent (#147) — save the window a step
/// across lands on, nearest by centre (#2619).
extension KiwiCore {
    /// Steps `focus`/`swap` in a track space: directions along
    /// the axis move within the focused track, directions
    /// across it jump to the adjacent track's window nearest by
    /// centre (#2619). Past an end, `focus` wraps when
    /// `wraps` (#168 twin, This screen, #2493: within the track along
    /// the axis, last <-> first track across it); `swap` never
    /// wraps. Nil falls through to the geometric search — which
    /// keeps cross-monitor focus alive and, with unequal track
    /// lengths, may pick a diagonally-nearest window past a
    /// track end rather than failing outright (the scrolling
    /// precedent's trade). A real edge with no tiled candidate
    /// falls to the float tier (#488); with no float that way
    /// it still fails cleanly.
    func trackStep(
        _ direction: Direction,
        space: Space,
        focused: WindowID,
        swapping: Bool,
        warp: Bool,
        wraps: Bool,
        skip lensSkip: (WindowID) -> Bool
    ) -> CommandResponse? {
        let params = tiler.settings.resolvedTrack(for: space.id)
        let tiled = state.effectiveTiledMembers(of: space)
        guard let index = tiled.firstIndex(of: focused) else {
            return nil
        }
        // The tracks the render draws — the automatic cap and the
        // overflow fold included — or a step "along" a track walks
        // across the ones the fold merged (#1488, #2235).
        let counts =
            (tiler.layoutInput(state: state)?.context)
            .map { TrackLayout.renderPartition(of: tiled, in: $0) }?
            .counts
            ?? TrackLayout.counts(
                of: tiled,
                breaks: space.trackBreaks,
                cap: params.trackCap
            )
        let ranges = TrackLayout.ranges(of: counts)
        guard
            let track = TrackLayout.trackIndex(
                ofWindowIndex: index,
                counts: counts
            )
        else { return nil }
        let vertical = params.axis == .vertical
        // Array-order twin of the geometric pile skip (#172):
        // when the focused window sits in an overflow cascade,
        // a swap steps past the pile's array indices to the
        // tiled entry outside it. Only for `swap`, only when
        // enabled; `pile` is empty (no skip) otherwise and for a
        // window that is not itself piled — so a plain swap is
        // untouched.
        let pile =
            swapping && tiler.settings.swapSkipsCascade
            ? trackPile(space: space, focused: focused)
            : []
        let skip: (WindowID) -> Bool = {
            pile.contains($0) || lensSkip($0)
        }
        let slots = shownSlots()
        let tie = navigationTie(
            from: focused,
            tiled: tiled,
            swapping: swapping
        )
        let target: WindowID?
        switch direction {
        case .up where vertical, .left where !vertical:
            target = alongTarget(
                step: -1,
                index: index,
                range: ranges[track],
                tiled: tiled,
                wrap: wraps,
                skip: skip
            )
        case .down where vertical, .right where !vertical:
            target = alongTarget(
                step: 1,
                index: index,
                range: ranges[track],
                tiled: tiled,
                wrap: wraps,
                skip: skip
            )
        case .left where vertical, .up where !vertical:
            target = acrossTarget(
                step: -1,
                track: track,
                ranges: ranges,
                tiled: tiled,
                slots: slots,
                origin: slots[focused],
                vertical: vertical,
                wrap: wraps,
                skip: skip,
                tie: tie
            )
        case .right where vertical, .down where !vertical:
            target = acrossTarget(
                step: 1,
                track: track,
                ranges: ranges,
                tiled: tiled,
                slots: slots,
                origin: slots[focused],
                vertical: vertical,
                wrap: wraps,
                skip: skip,
                tie: tie
            )
        default:
            target = nil
        }
        guard let target else {
            // A piled swap that found no window outside the pile
            // is a deliberate no-op — do not fall through to the
            // geometric search, which would re-enter the same
            // cascade. A non-piled nil still falls through (edge
            // steps, cross-monitor focus) and hits the geometric
            // dead-end cue there instead.
            if pile.isEmpty { return nil }
            flashDeadEnd(focused, direction: direction)
            return .fail("no window \(direction.rawValue) of focus")
        }
        if swapping {
            if refuseSwapOntoTraveler(target, in: space) {
                return .ok()
            }
            state.workspaces.withSpace(space.id) {
                $0.swap(focused, target)
            }
            retile(
                animated: tiler.settings.animations.onWindowSwap
            )
            scheduleTrackZOrderRestoreIfOverflowing()
        } else {
            focusWindow(target, warp: warp)
        }
        return .ok()
    }

    /// The next window within the track, stepping past any the
    /// `skip` predicate rejects (cascade-mates, #172; a lens's
    /// hazed windows, #2103 ruling 35) and wrapping at the ends
    /// when asked — a wrap asks `skip` too and never lands on the
    /// origin.
    private func alongTarget(
        step: Int,
        index: Int,
        range: Range<Int>,
        tiled: [WindowID],
        wrap: Bool,
        skip: (WindowID) -> Bool
    ) -> WindowID? {
        let base = range.lowerBound
        return Navigation.arrayStep(
            from: index - base,
            step: step,
            count: range.count,
            wrap: wrap,
            skip: { skip(tiled[base + $0]) }
        ).map { tiled[base + $0] }
    }

    /// The window beside `origin` in the nearest track holding a
    /// shown window `skip` accepts — a whole cascaded track is all
    /// pile-mates — wrapping last <-> first when asked, never onto
    /// the origin's track: the nearest by centre, a tie to `tie`
    /// (#2619). `slots` are the shown ones, so a run's hidden
    /// windows are never landed on.
    private func acrossTarget(
        step: Int,
        track: Int,
        ranges: [Range<Int>],
        tiled: [WindowID],
        slots: [WindowID: CGRect],
        origin: CGRect?,
        vertical: Bool,
        wrap: Bool,
        skip: (WindowID) -> Bool,
        tie: Navigation.TieBreak
    ) -> WindowID? {
        guard let origin else { return nil }
        func shown(_ track: Int) -> [(id: WindowID, frame: CGRect)] {
            tiled[ranges[track]].compactMap { id in
                guard !skip(id), let frame = slots[id] else { return nil }
                return (id, frame)
            }
        }
        guard
            let next = Navigation.arrayStep(
                from: track,
                step: step,
                count: ranges.count,
                wrap: wrap,
                skip: { shown($0).isEmpty }
            )
        else { return nil }
        return Navigation.beside(
            origin,
            crossIsY: vertical,
            candidates: shown(next),
            tie: tie
        )
    }

    /// The focused window's overflow-cascade pile in a track
    /// space (#172), from the layout's live slots — empty when it
    /// is not piled. Shares `Navigation.pileMates` with the
    /// geometric layouts; the track path then skips these array
    /// indices rather than excluding geometric candidates.
    private func trackPile(
        space: Space,
        focused: WindowID
    ) -> Set<WindowID> {
        // A run's hidden windows are no cascade (#2235): a swap
        // steps into them like any track member.
        let slots = shownSlots()
        let tiled = state.effectiveTiledMembers(of: space)
            .compactMap { id -> (id: WindowID, frame: CGRect)? in
                guard let frame = slots[id] else { return nil }
                return (id, frame)
            }
        return Navigation.pileMates(of: focused, among: tiled)
    }

    /// `move_to_track("prev"|"next")` (#128): moves the focused
    /// window into the adjacent track in the sequence, opening
    /// a new edge track past the ends (keyboard parity with
    /// drag & drop and own-track spawning). Never wraps.
    func moveToTrack(_ args: [JSONValue]) -> CommandResponse {
        // prev/next, not compass directions (#185 review): the
        // track verbs operate on the 1D track sequence, so the
        // sequence vocabulary is the honest one — it kills the
        // per-axis inert direction pair and survives an axis
        // flip. prev = lower tiled index (the track to the
        // LEFT with a vertical axis, ABOVE with a horizontal
        // one); next = higher (right/below). Focus and swap
        // stay spatial — see `trackStep`.
        guard let raw = args.first?.stringValue,
            let delta = Self.trackSequenceDelta(raw)
        else {
            return .fail("expected prev|next")
        }
        guard let space = activeSpace else {
            return .fail("no active space")
        }
        guard space.mode == .track else {
            return .fail("move_to_track needs a track space")
        }
        guard let focused = state.focusAnchor(of: space),
            state.windows[focused]?.isFloating == false
        else {
            return .fail("no focused tiled window")
        }
        // A focused traveler (injected, not a local member) has no
        // track to move within this space — refuse with the home-
        // space pill (#435), like swap-from-traveler.
        if refuseSwapOntoTraveler(focused, in: space) {
            return .ok()
        }
        let params = tiler.settings.resolvedTrack(for: space.id)
        // Snapshot float verdicts first: the withSpace closure
        // must not touch `state` while it is being mutated.
        let floating = Set(
            space.windows.filter {
                state.windows[$0]?.isFloating == true
            }
        )
        var moved = false
        state.workspaces.withSpace(space.id) {
            moved = $0.moveWindowToTrack(
                focused,
                delta: delta,
                cap: params.trackCap,
                isTiled: { !floating.contains($0) }
            )
        }
        guard moved else {
            return .fail("no \(raw) track of focus")
        }
        retile(
            animated: tiler.settings.animations.onWindowSwap
        )
        scheduleTrackZOrderRestoreIfOverflowing()
        return .ok()
    }

    /// The one prev/next parser both track sequence verbs use
    /// (`move_to_track`, `track.swap`): prev = -1 (lower tiled
    /// index), next = +1. One spelling only — no `previous`
    /// alias (one-vocabulary rule).
    static func trackSequenceDelta(_ raw: String) -> Int? {
        switch raw {
        case "prev": return -1
        case "next": return 1
        default: return nil
        }
    }
}
