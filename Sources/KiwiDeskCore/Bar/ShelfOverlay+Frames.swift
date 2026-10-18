import AppKit

/// The shelf's pure frame arithmetic (#1517), split from
/// `ShelfOverlay.swift` at the §2.1 ceiling.
extension ShelfOverlay {
    /// The grip: centred on the divider line, `reach` across it
    /// and the shelf's whole depth along it.
    nonisolated static func handleFrame(
        divider: CGRect,
        depth: CGFloat,
        horizontal: Bool
    ) -> CGRect {
        let reach = ShelfDividerHandle.reach
        return horizontal
            ? CGRect(
                x: divider.midX - reach / 2,
                y: 0,
                width: reach,
                height: depth
            )
            : CGRect(
                x: 0,
                y: divider.midY - reach / 2,
                width: depth,
                height: reach
            )
    }

    /// The one plate under both sections, in strip coordinates,
    /// the shelf's whole depth over `ShelfArrangement.plateSpan`
    /// of what each section's run asks for.
    nonisolated static func plateFrame(
        sections: [Section],
        strip: CGRect,
        horizontal: Bool,
        shelf: KiwiShelf
    ) -> CGRect? {
        let asks = sections.compactMap { section -> ClosedRange<CGFloat>? in
            guard !section.plate.isEmpty else { return nil }
            let ask = section.plate.offsetBy(
                dx: section.slot.minX - strip.minX,
                dy: section.slot.minY - strip.minY
            )
            return horizontal ? ask.minX...ask.maxX : ask.minY...ask.maxY
        }
        guard
            let span = ShelfArrangement.plateSpan(
                asks: asks,
                length: horizontal ? strip.width : strip.height,
                shelf: shelf
            )
        else { return nil }
        let extent = span.upperBound - span.lowerBound
        return horizontal
            ? CGRect(
                x: span.lowerBound,
                y: 0,
                width: extent,
                height: strip.height
            )
            : CGRect(
                x: 0,
                y: span.lowerBound,
                width: strip.width,
                height: extent
            )
    }
}
