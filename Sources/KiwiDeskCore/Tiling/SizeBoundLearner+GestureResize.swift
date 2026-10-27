import CoreGraphics

/// The ledger's answer to a user's resize gesture (#2706): a drag
/// changes the window's size, not the app's constraints, so it
/// unlearns only what the size it shows contradicts. An app
/// re-bounding itself still takes `forget`.
extension SizeBoundLearner {
    /// The window now holds `size` by the user's hand. The open ask
    /// and a pending probe's issue are retired as a park retires
    /// them, the candidates go (no ask of ours produced this size),
    /// and a believed entry stays unless `size` falsifies it — so a
    /// floor capping Grid survives the drag that grows its window.
    mutating func gestureResized(_ id: WindowID, to size: CGSize) {
        parkRetiresAsk(id)
        candidates[id] = nil
        probes[id]?.width.pending?.baselineTrusted = false
        probes[id]?.height.pending?.baselineTrusted = false
        guard let ledger = bounds[id] else { return }
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
    }
}
