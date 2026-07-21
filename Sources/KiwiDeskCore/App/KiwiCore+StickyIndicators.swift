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
            spaceName: stickyHomeLabel(home)
        )
    }

    /// A named space is its own label; a numeric id reads as
    /// "Space N" so the pill never shows a bare digit.
    private func stickyHomeLabel(_ id: SpaceID) -> String {
        Int(id.raw) != nil
            ? L("sticky.home.space", "Space %1$@", id.raw)
            : id.raw
    }
}
