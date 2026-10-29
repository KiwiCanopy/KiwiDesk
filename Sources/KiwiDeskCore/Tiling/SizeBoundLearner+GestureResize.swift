import CoreGraphics

/// The ledger's answer to a user's resize gesture (#2706): a drag
/// changes the window's size, not the app's constraints, so it
/// unlearns only what the size it shows contradicts. An app
/// re-bounding itself still takes `forget`.
extension SizeBoundLearner {
    /// The window now holds `size` by the user's hand. The open ask
    /// is retired as a park retires it, so a probe in flight is
    /// re-sent later (#2758), its baseline distrusted; the candidates
    /// go (no ask of ours produced this size), and a believed
    /// entry stays unless `size` falsifies it — so a
    /// floor capping Grid survives the drag that grows its window.
    /// Returns whether a believed entry was dropped.
    @discardableResult
    mutating func gestureResized(
        _ id: WindowID,
        to size: CGSize
    ) -> Bool {
        supersedeAsk(id)
        candidates[id] = nil
        distrustProbeBaselines(id)
        guard let ledger = bounds[id] else { return false }
        writeBounds(
            id,
            entries: ledger.width.filter {
                !$0.isContradicted(by: size.width)
            },
            axis: \.width
        )
        writeBounds(
            id,
            entries: ledger.height.filter {
                !$0.isContradicted(by: size.height)
            },
            axis: \.height
        )
        let kept =
            (bounds[id]?.width.count ?? 0)
            + (bounds[id]?.height.count ?? 0)
        return kept < ledger.width.count + ledger.height.count
    }
}
