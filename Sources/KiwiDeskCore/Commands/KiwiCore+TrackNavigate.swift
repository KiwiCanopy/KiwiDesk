import AppKit
import Foundation

/// Track-mode navigation (#128): array-order focus/swap stepping
/// and `move_to_track`, split out of `KiwiCore+NavigateCommand`
/// for file size. Array order IS spatial order inside a track
/// (and track order across them), so stepping is pure index math
/// — the maintainer-preferred scrolling precedent (#147); no
/// geometric search.
extension KiwiCore {
    /// Steps `focus`/`swap` in a track space: directions along
    /// the axis move within the focused track, directions
    /// across it jump to the same relative position in the
    /// adjacent track. Past an end, `focus` wraps when
    /// `wrap_focus` is on (#168 twin: within the track along
    /// the axis, last <-> first track across it); `swap` never
    /// wraps. Nil falls through to the geometric search — which
    /// keeps cross-monitor focus alive and, with unequal track
    /// lengths, may pick a diagonally-nearest window past a
    /// track end rather than failing outright (the scrolling
    /// precedent's trade; a real edge with no candidate still
    /// fails cleanly).
    func trackStep(
        _ direction: Direction,
        space: Space,
        focused: WindowID,
        swapping: Bool
    ) -> CommandResponse? {
        let params =
            tiler.settings.resolvedTrack(for: space.id)
        let tiled = space.windows.filter {
            state.windows[$0]?.isFloating == false
        }
        guard let index = tiled.firstIndex(of: focused) else {
            return nil
        }
        let counts = TrackLayout.counts(
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
        let skip: (WindowID) -> Bool = { pile.contains($0) }
        let target: WindowID?
        switch direction {
        case .up where vertical, .left where !vertical:
            target = alongTarget(
                step: -1,
                index: index,
                range: ranges[track],
                tiled: tiled,
                wrap: params.wrapFocus && !swapping,
                skip: skip
            )
        case .down where vertical, .right where !vertical:
            target = alongTarget(
                step: 1,
                index: index,
                range: ranges[track],
                tiled: tiled,
                wrap: params.wrapFocus && !swapping,
                skip: skip
            )
        case .left where vertical, .up where !vertical:
            target = acrossTarget(
                step: -1,
                index: index,
                track: track,
                ranges: ranges,
                tiled: tiled,
                wrap: params.wrapFocus && !swapping,
                skip: skip
            )
        case .right where vertical, .down where !vertical:
            target = acrossTarget(
                step: 1,
                index: index,
                track: track,
                ranges: ranges,
                tiled: tiled,
                wrap: params.wrapFocus && !swapping,
                skip: skip
            )
        default:
            target = nil
        }
        guard let target else {
            // A piled swap that found no window outside the pile
            // is a deliberate no-op — do not fall through to the
            // geometric search, which would re-enter the same
            // cascade. A non-piled nil still falls through (edge
            // steps, cross-monitor focus).
            return pile.isEmpty
                ? nil
                : .fail("no window \(direction.rawValue) of focus")
        }
        if swapping {
            state.workspaces.withSpace(space.id) {
                $0.swap(focused, target)
            }
            retile(
                animated: tiler.settings.animations.onWindowSwap
            )
        } else {
            focusWindow(target)
        }
        return .ok()
    }

    /// The next window within the track, stepping past any the
    /// `skip` predicate rejects (cascade-mates, #172), and
    /// wrapping at the ends when asked (a lone window never wraps
    /// onto itself). Wrap and skip never co-occur: wrap is a
    /// `focus`-only concession, skip a `swap`-only one.
    private func alongTarget(
        step: Int,
        index: Int,
        range: Range<Int>,
        tiled: [WindowID],
        wrap: Bool,
        skip: (WindowID) -> Bool
    ) -> WindowID? {
        var next = index + step
        while range.contains(next) {
            if !skip(tiled[next]) { return tiled[next] }
            next += step
        }
        guard wrap, range.count > 1 else { return nil }
        return tiled[
            step > 0 ? range.lowerBound : range.upperBound - 1
        ]
    }

    /// The window at the same relative position (clamped) in the
    /// nearest track the `skip` predicate accepts, wrapping last
    /// <-> first when asked. Skipping steps across further tracks
    /// (a whole cascaded track is all pile-mates); wrap applies
    /// only to `focus`, where skip is inert.
    private func acrossTarget(
        step: Int,
        index: Int,
        track: Int,
        ranges: [Range<Int>],
        tiled: [WindowID],
        wrap: Bool,
        skip: (WindowID) -> Bool
    ) -> WindowID? {
        let offset = index - ranges[track].lowerBound
        func mapped(_ range: Range<Int>) -> WindowID {
            tiled[range.lowerBound + min(offset, range.count - 1)]
        }
        var target = track + step
        while ranges.indices.contains(target) {
            let candidate = mapped(ranges[target])
            if !skip(candidate) { return candidate }
            target += step
        }
        guard wrap, ranges.count > 1 else { return nil }
        return mapped(ranges[step > 0 ? 0 : ranges.count - 1])
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
        let slots = tiler.calculatedFrames(state: state)
        let tiled = space.windows.compactMap {
            id -> (id: WindowID, frame: CGRect)? in
            guard state.windows[id]?.isFloating == false,
                let frame = slots[id]
            else { return nil }
            return (id, frame)
        }
        return Navigation.pileMates(of: focused, among: tiled)
    }

    /// `move_to_track(direction)` (#128): moves the focused
    /// window into the adjacent track across the axis, opening
    /// a new edge track past the ends (keyboard parity with
    /// drag & drop and own-track spawning). Never wraps.
    func moveToTrack(_ args: [JSONValue]) -> CommandResponse {
        guard let raw = args.first?.stringValue,
            let direction = Direction(rawValue: raw)
        else {
            return .fail("expected left|right|up|down")
        }
        guard let space = activeSpace else {
            return .fail("no active space")
        }
        guard space.mode == .track else {
            return .fail("move_to_track needs a track space")
        }
        guard let focused = space.focused,
            state.windows[focused]?.isFloating == false
        else {
            return .fail("no focused tiled window")
        }
        let params =
            tiler.settings.resolvedTrack(for: space.id)
        let vertical = params.axis == .vertical
        let delta: Int
        switch direction {
        case .left where vertical, .up where !vertical:
            delta = -1
        case .right where vertical, .down where !vertical:
            delta = 1
        default:
            return .fail(
                "move_to_track moves across the tracks — "
                    + (vertical
                        ? "expected left|right"
                        : "expected up|down")
            )
        }
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
            return .fail("no track \(raw) of focus")
        }
        retile(
            animated: tiler.settings.animations.onWindowSwap
        )
        return .ok()
    }
}
