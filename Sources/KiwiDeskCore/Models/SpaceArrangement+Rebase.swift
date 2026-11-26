import Foundation

/// A stored undo arrangement rebased over a window that opened or
/// closed (#3601), through the live placement code so a step
/// replays the same edit the Space took.
extension SpaceArrangement {
    /// This arrangement with `window` gone, by `Space.remove`, so a
    /// track break hands on as it did live.
    func removing(_ window: WindowID) -> SpaceArrangement {
        guard windows.contains(window) else { return self }
        var space = scratch(focused: nil)
        space.remove(window)
        return SpaceArrangement(space, sessionSizes: sessionSizes)
    }

    /// This arrangement with `window` placed by `placement` beside
    /// `anchor` — at the end when `anchor` is not a member — and
    /// carrying the per-window sizing `live` gave it: a mirror of
    /// the window-keyed fields `SpaceArrangementParityTests` holds.
    func inserting(
        _ window: WindowID,
        placement: SpawnPlacement,
        anchor: WindowID?,
        from live: SpaceArrangement
    ) -> SpaceArrangement {
        guard !windows.contains(window) else { return self }
        let focus = anchor.flatMap { windows.contains($0) ? $0 : nil }
        var space = scratch(focused: focus)
        space.insert(window, placement: placement)
        var out = SpaceArrangement(space, sessionSizes: sessionSizes)
        out.stackWeights[window] = live.stackWeights[window]
        out.runSizes[window] = live.runSizes[window]
        out.trackWeights[window] = live.trackWeights[window]
        if live.trackBreaks.contains(window) {
            out.trackBreaks.insert(window)
        }
        if live.handedBreaks.contains(window) {
            out.handedBreaks.insert(window)
        }
        return out
    }

    /// A Space holding this arrangement, through `restore`, the
    /// parity-tested inverse of `init`.
    private func scratch(focused: WindowID?) -> Space {
        var space = Space(
            id: SpaceID("undo"),
            mode: mode,
            windows: windows,
            focused: focused
        )
        space.restore(self)
        return space
    }
}
