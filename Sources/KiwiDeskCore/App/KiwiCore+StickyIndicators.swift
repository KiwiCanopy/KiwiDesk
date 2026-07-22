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
        let color = tiler.settings.stickyStyle.color
        stickyIndicators.sync(
            sticky.map {
                StickyIndicatorManager.Spec(
                    window: $0.id,
                    frame: $0.frame,
                    color: color
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

    /// Refuses a swap whose `target` is a tiled-sticky traveler.
    /// A traveler is injected into the active space's layout but is
    /// not a member of it, so `Space.swap`'s membership guard would
    /// silently no-op the exchange (#414 v2). Flash the home-space
    /// pill on the traveler — the window that can't move, not the
    /// trier — and report the refusal so the caller skips the dead
    /// swap (#435). Returns `false` for a normal member: the swap
    /// proceeds. No snap-back animation on the keyboard path, so the
    /// pill's own entrance micro-pop carries the acknowledgement.
    /// Guards both swap ends: `navigate` also passes the ORIGIN
    /// (the focus anchor), since swapping FROM a traveler is the
    /// same dead `Space.swap` no-op with the same explanation.
    func refuseSwapOntoTraveler(
        _ target: WindowID,
        in space: Space
    ) -> Bool {
        guard !space.windows.contains(target) else { return false }
        flashStickyHomeSpace(target)
        return true
    }

    /// Refuses a swap that would push a sticky FOCUSED window into
    /// the overflow pile (#438). A sticky window is pile-exempt
    /// (#414 v2) — it always keeps a tiled cell, so swapping it onto
    /// a piled `target` is futile: the retile snaps it straight back
    /// and only reshuffles a neighbour into the pile. Detect the
    /// piled target with the shared cascade detector (#172), flash a
    /// cue on the sticky window, and report the refusal so the caller
    /// skips the dead swap. A third, distinct vocabulary from the
    /// traveler pill (#435) and the dead-end bounce (#436). Returns
    /// `false` for any normal swap (non-sticky focus, or a tiled
    /// target).
    func refuseStickyIntoPile(
        _ focused: WindowID,
        target: WindowID,
        among slots: [(id: WindowID, frame: CGRect)]
    ) -> Bool {
        guard state.windows[focused]?.isSticky == true,
            !Navigation.pileMates(of: target, among: slots).isEmpty
        else { return false }
        flashStickyCannotPile(focused)
        return true
    }

    /// Expands a sticky window's chip into a pill explaining it can't
    /// be sent to the overflow pile (#438). Gated by the same
    /// `sticky.indicator` as the chip; a no-op for a non-sticky
    /// window or when the mark is off. No relayout precedes it (the
    /// swap is refused outright), so it appears at once.
    func flashStickyCannotPile(_ id: WindowID) {
        guard tiler.settings.stickyStyle.indicator else { return }
        stickyIndicators.flash(
            id,
            format: L(
                "sticky.pile.pill",
                "Sticky windows can't be moved to the pile"
            ),
            mark: .text(""),
            delay: 0.05
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
