import CoreGraphics

/// Drives the focus-border overlays (#278). `updateBorders()`
/// snapshots the active space and hands the manager the desired
/// rings; the "who gets a ring" decision is a pure static
/// function so it stays actor-free and unit-testable.
///
/// Cross-layout model (AGENTS.md §5): overflow piles
/// (`OverlapStack`) get exactly one ring — the visible
/// top-of-pile — via `Navigation.pileMates`; monocle is always
/// focused-only regardless of `unfocused_enabled`, since only the
/// focused window is visible.
extension KiwiCore {
    func updateBorders() {
        let style = tiler.settings.borderStyle
        guard style.enabled, let space = activeSpace else {
            borders.sync([])
            return
        }
        // AX-coordinate frames from cached window state — never a
        // live AX call. A window without a known frame yet is
        // simply not bordered until its next echo.
        let slots = space.windows.compactMap {
            id -> (id: WindowID, frame: CGRect)? in
            guard let frame = state.windows[id]?.frame else {
                return nil
            }
            return (id: id, frame: frame)
        }
        borders.sync(
            Self.borderSpecs(
                style: style,
                focused: space.focused,
                slots: slots,
                isMonocle: space.mode == .monocle
            )
        )
    }

    /// The rings to show for one space. Focused window always
    /// (when borders are on); every other visible slot only when
    /// `unfocusedEnabled` and the space isn't monocle. Piles
    /// collapse to a single ring on their top window.
    static func borderSpecs(
        style: BorderStyle,
        focused: WindowID?,
        slots: [(id: WindowID, frame: CGRect)],
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
        // Exclude the focused window's pile-mates (buried behind
        // it), then walk the rest, taking one representative per
        // remaining pile so each visible slot gets a single ring.
        let focusedPile = Navigation.pileMates(
            of: focused,
            among: slots
        )
        var remaining = slots.filter {
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
            let pile = Navigation.pileMates(
                of: next.id,
                among: slots
            )
            remaining.removeAll {
                $0.id == next.id || pile.contains($0.id)
            }
        }
        return specs
    }
}
