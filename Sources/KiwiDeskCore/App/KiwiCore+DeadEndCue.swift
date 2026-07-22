import AppKit

extension KiwiCore {
    /// Fires the dead-end rubber-band on the focused ring when a
    /// directional focus/swap finds no window that way (#436) — a
    /// wordless "nothing there," distinct from the semantic pill
    /// (#435). Pure overlay motion: the ring bumps toward the wall
    /// and springs back; the window never moves.
    ///
    /// The ring style is resolved from settings even when borders
    /// are off, so a transient overlay can carry the cue — the
    /// feedback is universal, not a borders-on perk. Reduce Motion
    /// swaps the offset for an opacity pulse (handled downstream).
    func flashDeadEnd(_ focused: WindowID, direction: Direction) {
        guard
            let frame = tiler.calculatedFrames(state: state)[focused]
                ?? state.windows[focused]?.frame
        else { return }
        let style = tiler.settings.borderStyle
        borders.flashDeadEnd(
            window: focused,
            frame: frame,
            direction: direction,
            colorHex: style.focusedColor,
            width: style.clampedWidth,
            cornerStyle: style.cornerStyle,
            reduceMotion: NSWorkspace.shared
                .accessibilityDisplayShouldReduceMotion
        )
    }
}
