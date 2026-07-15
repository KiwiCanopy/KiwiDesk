import CoreGraphics

/// Drives the focus-border overlays (#278). `updateBorders()`
/// snapshots the active space and hands the manager the desired
/// rings; the "who gets a ring" decision (`borderSpecs`) is a pure
/// `nonisolated` function so it stays actor-free and
/// unit-testable.
///
/// Cross-layout model (AGENTS.md §5): overflow piles
/// (`OverlapStack`) get exactly one ring — its representative — via
/// `Navigation.pileMates`; monocle is always focused-only
/// regardless of `unfocused_enabled`, since only the focused
/// window is visible. Only tiled windows form piles, so floating
/// windows are excluded from the pile detector (a floating dialog
/// over a tiled window is not a cascade mate).
extension KiwiCore {
    func updateBorders() {
        let style = tiler.settings.borderStyle
        guard style.enabled, let space = activeSpace else {
            borders.sync([])
            return
        }
        // Layout targets are the truth for a settled window; a
        // window mid-animation keeps its current (cached) frame
        // and is caught up by the per-tick follow, so the ring
        // never flashes to the target ahead of the slide. Reading
        // targets also fixes instant retiles (space switch), where
        // the cached frame still holds the off-screen stash.
        let targets = tiler.calculatedFrames(state: state)
        let floating = Set(
            space.windows.filter {
                state.windows[$0]?.isFloating == true
            }
        )
        let slots = space.windows.compactMap {
            id -> (id: WindowID, frame: CGRect)? in
            let frame =
                tiler.animation.isAnimating(window: id)
                ? state.windows[id]?.frame
                : targets[id] ?? state.windows[id]?.frame
            guard let frame else { return nil }
            return (id: id, frame: frame)
        }
        borders.sync(
            Self.borderSpecs(
                style: style,
                focused: space.focused,
                slots: slots,
                floating: floating,
                isMonocle: space.mode == .monocle
            )
        )
    }

    /// The rings to show for one space. Focused window always
    /// (when borders are on); every other visible tiled slot only
    /// when `unfocusedEnabled` and the space isn't monocle. Piles
    /// collapse to a single ring on one representative member.
    /// Pure over the flat slot list — no `self`, no AX.
    nonisolated static func borderSpecs(
        style: BorderStyle,
        focused: WindowID?,
        slots: [(id: WindowID, frame: CGRect)],
        floating: Set<WindowID>,
        isMonocle: Bool
    ) -> [BorderManager.Spec] {
        guard style.enabled, let focused,
            let focusedFrame = slots.first(where: {
                $0.id == focused
            })?.frame
        else { return [] }
        let width = style.clampedWidth
        var specs = [
            BorderManager.Spec(
                window: focused,
                frame: focusedFrame,
                colorHex: style.focusedColor,
                width: width,
                cornerStyle: style.cornerStyle
            )
        ]
        guard style.unfocusedEnabled, !isMonocle else {
            return specs
        }
        // Only tiled windows form overflow piles, so run the pile
        // detector over tiled slots alone — a floating window
        // overlapping a tiled one is not a cascade mate, and
        // floating windows get no unfocused ring (they overlap
        // arbitrarily; the focused float is still ringed above).
        let tiled = slots.filter { !floating.contains($0.id) }
        let focusedPile = Navigation.pileMates(
            of: focused,
            among: tiled
        )
        var remaining = tiled.filter {
            $0.id != focused && !focusedPile.contains($0.id)
        }
        while let next = remaining.first {
            specs.append(
                BorderManager.Spec(
                    window: next.id,
                    frame: next.frame,
                    colorHex: style.unfocusedColor,
                    width: width,
                    cornerStyle: style.cornerStyle
                )
            )
            // One ring per pile: drop this representative and its
            // mates (array-first member, not necessarily the
            // visual top — the rings render regardless of z-order).
            let pile = Navigation.pileMates(
                of: next.id,
                among: tiled
            )
            remaining.removeAll {
                $0.id == next.id || pile.contains($0.id)
            }
        }
        return specs
    }
}
