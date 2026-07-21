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
}
