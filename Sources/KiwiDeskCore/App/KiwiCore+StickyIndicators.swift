import AppKit
import CoreGraphics

/// Drives the on-window sticky marks (#414): every sticky
/// window wears the chip, on every space — a sticky window is
/// visible everywhere, so its mark is too. Gated only by
/// `sticky.indicator`; deliberately NOT by `border.enabled`
/// (the mark is a border sibling, not a border feature).
extension KiwiCore {
    func updateStickyIndicators() {
        guard tiler.settings.stickyStyle.indicator else {
            stickyIndicators.sync([])
            borders.setStickyTracked([])
            return
        }
        let sticky = state.windows.all.filter(\.isSticky)
        stickyIndicators.sync(
            sticky.map {
                StickyIndicatorManager.Spec(
                    window: $0.id,
                    frame: $0.frame
                )
            }
        )
        // Fold sticky windows into the ring's WS watch set so the
        // chip gets z-order/frame events even with no border (#414).
        borders.setStickyTracked(Set(sticky.map(\.id)))
    }

    /// #421: when a tiled-sticky traveler snaps back after a drag
    /// on a FOREIGN space, briefly expand its chip into a pill
    /// naming its home space — the one moment the "where does this
    /// belong?" question exists (ui-designer 2026-07-21). Guarded
    /// by the same `sticky.indicator` gate as the chip; a no-op
    /// for a non-sticky window (no chip to expand).
    func flashStickyHomeSpace(_ id: WindowID) {
        guard tiler.settings.stickyStyle.indicator,
            let home = state.workspaces.space(of: id)
        else { return }
        stickyIndicators.flash(
            id,
            format: L(
                "sticky.home.pill",
                "Can only be moved in its home space %1$@"
            ),
            mark: homeSpaceMark(home),
            delay: snapBackSettleDelay
        )
    }

    /// How long to hold the pill back so it appears only once the
    /// snap-back has settled: the relayout animation duration (the
    /// snap-back is an `onRelayout` reflow) plus a small buffer, or
    /// nearly instant when relayout animation is off. Tracks the
    /// live animation-speed setting, so a slow or long snap-back no
    /// longer spawns the pill early.
    private var snapBackSettleDelay: TimeInterval {
        guard tiler.settings.animations.onRelayout else {
            return 0.05
        }
        return Double(tiler.settings.animations.durationMS) / 1000
            + 0.08
    }

    /// The pill's home-space mark: the space's configured Space Bar
    /// icon (SF Symbol or emoji/character) so the pill matches the
    /// bar tile, else the bare id/name. Mirrors `spaceIdentifier`'s
    /// icon lookup but falls back to the FULL id — the pill has room
    /// for a real name, unlike the bar's 2-char monogram.
    private func homeSpaceMark(_ id: SpaceID) -> SpaceMark {
        if let icon = tiler.settings.spaceIcons[id], !icon.isEmpty {
            let isSymbol =
                NSImage(
                    systemSymbolName: icon,
                    accessibilityDescription: nil
                ) != nil
            return isSymbol ? .symbol(icon) : .text(icon)
        }
        return .text(id.raw)
    }
}
