import AppKit

/// Each App Bar item's `BarVisibility` (#2234), read from the frames
/// the retile issues and the order KiwiDesk intends — no
/// WindowServer read on the bar's refresh path. The bar's own screen
/// judges it: the space's screen's visible bounds.
extension KiwiCore {
    /// The verdict per window of `space`'s tiled members and
    /// `floats`. A float sits above every tile, the focused float
    /// above the other floats; a tile sits beneath the tiles the
    /// scrolling raise order puts over it, the focus on top — which
    /// is monocle's stack too.
    func appBarVisibility(
        of space: Space,
        floats: [WindowID]
    ) -> [WindowID: BarVisibility] {
        guard let screen = TilingEngine.screen(for: space.id, in: state)
        else { return [:] }
        let bounds = tiler.visibleBounds(screen)
        let issued = tiler.placedFrames(state: state, recording: false)
        let tiled = state.effectiveTiledMembers(of: space)
        let focus = appBarFocused(of: space)
        let floatFrame = { (id: WindowID) in
            self.tiler.commandedFrame(of: id) ?? self.state.windows[id]?.frame
        }
        let order =
            focus.flatMap { tiled.firstIndex(of: $0) }.map {
                Self.scrollingRaiseOrder(tiled, focusIndex: $0) + [tiled[$0]]
            } ?? []
        let floatFrames = floats.compactMap(floatFrame)
        var verdicts: [WindowID: BarVisibility] = [:]
        for id in tiled {
            let rank = order.firstIndex(of: id)
            let over = rank.map { order[($0 + 1)...] } ?? []
            verdicts[id] = judge(
                issued[id],
                on: bounds,
                above: over.compactMap { issued[$0] } + floatFrames
            )
        }
        for id in floats {
            let over =
                focus != id && focus.map(floats.contains) == true
                ? focus.flatMap(floatFrame).map { [$0] } ?? [] : []
            verdicts[id] = judge(floatFrame(id), on: bounds, above: over)
        }
        return verdicts
    }

    private func judge(
        _ frame: CGRect?,
        on bounds: CGRect,
        above: [CGRect]
    ) -> BarVisibility {
        BarVisibility.judge(
            frame,
            on: bounds,
            above: above,
            parked: frame.map(tiler.looksStashed) ?? false
        )
    }
}
