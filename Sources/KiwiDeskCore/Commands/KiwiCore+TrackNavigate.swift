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
    /// wraps. Nil falls through to the geometric search, which
    /// cleanly fails at the real edges.
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
            cap: params.count
        )
        let ranges = TrackLayout.ranges(of: counts)
        guard
            let track = TrackLayout.trackIndex(
                ofWindowIndex: index,
                counts: counts
            )
        else { return nil }
        let vertical = params.axis == .vertical
        let target: WindowID?
        switch direction {
        case .up where vertical, .left where !vertical:
            target = alongTarget(
                step: -1,
                index: index,
                range: ranges[track],
                tiled: tiled,
                wrap: params.wrapFocus && !swapping
            )
        case .down where vertical, .right where !vertical:
            target = alongTarget(
                step: 1,
                index: index,
                range: ranges[track],
                tiled: tiled,
                wrap: params.wrapFocus && !swapping
            )
        case .left where vertical, .up where !vertical:
            target = acrossTarget(
                step: -1,
                index: index,
                track: track,
                ranges: ranges,
                tiled: tiled,
                wrap: params.wrapFocus && !swapping
            )
        case .right where vertical, .down where !vertical:
            target = acrossTarget(
                step: 1,
                index: index,
                track: track,
                ranges: ranges,
                tiled: tiled,
                wrap: params.wrapFocus && !swapping
            )
        default:
            target = nil
        }
        guard let target else { return nil }
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

    /// The next window within the track, wrapping at its ends
    /// when asked (a lone window never wraps onto itself).
    private func alongTarget(
        step: Int,
        index: Int,
        range: Range<Int>,
        tiled: [WindowID],
        wrap: Bool
    ) -> WindowID? {
        let next = index + step
        if range.contains(next) { return tiled[next] }
        guard wrap, range.count > 1 else { return nil }
        return tiled[
            step > 0 ? range.lowerBound : range.upperBound - 1
        ]
    }

    /// The window at the same relative position (clamped) in
    /// the adjacent track, wrapping last <-> first when asked.
    private func acrossTarget(
        step: Int,
        index: Int,
        track: Int,
        ranges: [Range<Int>],
        tiled: [WindowID],
        wrap: Bool
    ) -> WindowID? {
        var target = track + step
        if !ranges.indices.contains(target) {
            guard wrap, ranges.count > 1 else { return nil }
            target = step > 0 ? 0 : ranges.count - 1
        }
        let offset = index - ranges[track].lowerBound
        let range = ranges[target]
        return tiled[
            range.lowerBound
                + min(offset, range.count - 1)
        ]
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
                cap: params.count,
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
