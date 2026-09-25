import AppKit

/// The section break between the layer item and the Spaces
/// (#1169) — the front-app segment's rule, at the other end of
/// the run. It rides the run: the layer item's slot is widened
/// by the rule and a gap, so scrolling, hugging and the plate
/// measure it, and the item view is drawn in the slot's leading
/// part with the rule after it.
extension SpaceBarOverlay {
    /// Axis length the rule adds to the layer item's slot.
    nonisolated static func layerDividerExtent(
        gap: CGFloat
    ) -> CGFloat {
        gap + BarDivider.sectionThickness
    }

    /// Whether `items` lead with the layer item — the one place
    /// it can sit (`KiwiCore.spaceBar(for:)` prepends it).
    nonisolated static func leadsWithLayer(_ items: [Item]) -> Bool {
        items.first?.space == nil && !items.isEmpty
    }

    /// Trims the leading slot back to the item's own length and
    /// lays the rule out in the trimmed-off part; hides it when
    /// no layer item leads. Returns the frames the views take.
    func layoutLayerDivider(
        frames: [CGRect],
        leads: Bool,
        gap: CGFloat,
        strip: CGRect,
        horizontal: Bool,
        style: SpaceBarLook
    ) -> [CGRect] {
        guard leads, let slot = frames.first else {
            layerDivider.isHidden = true
            return frames
        }
        let extent = Self.layerDividerExtent(gap: gap)
        var item = slot
        if horizontal {
            item.size.width = max(slot.width - extent, 0)
        } else {
            item.size.height = max(slot.height - extent, 0)
        }
        let depth = horizontal ? strip.height : strip.width
        layerDivider.isHidden = false
        layerDivider.layer?.backgroundColor =
            BarDivider.color(textColor: style.itemColor).cgColor
        layerDivider.frame = BarDivider.frame(
            at: (horizontal ? item.maxX : item.maxY) + gap,
            depth: depth,
            horizontal: horizontal,
            thickness: BarDivider.sectionThickness,
            lengthShare: BarDivider.sectionLengthShare
        )
        var trimmed = frames
        trimmed[0] = item
        return trimmed
    }
}
