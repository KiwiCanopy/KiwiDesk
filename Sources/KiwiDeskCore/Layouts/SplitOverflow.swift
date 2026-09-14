import CoreGraphics

/// The inward overflow placement for the split layouts (#934,
/// owner ruling 2026-08-31): a slot narrower than its window's
/// learned floor is emitted AT that floor, shifted so the frame
/// stays inside the layout region — the app's refusal then lands
/// where the frame already is, and a window that cannot fit
/// overflows toward the screen's centre rather than past its
/// edge. Scrolling re-packs and monocle centre on their own
/// (#677), and grid keeps the slot.
/// It runs on the frames the retile ISSUES
/// (`TilingEngine.placedFrames`), never on the slots
/// `calculatedFrames` hands a reader that classifies them: an
/// inward frame overlaps its neighbour by construction, and
/// `BspSplit.sides`, the drag pipeline or geometric navigation
/// would read that overlap as a pile.
public enum SplitOverflow {
    /// The frames a pass issues for `mode`: bsp and stack take
    /// the inward post-pass, every other layout its slots as
    /// they are.
    public static func placed(
        mode: LayoutMode,
        frames: [WindowID: CGRect],
        context: LayoutContext
    ) -> [WindowID: CGRect] {
        switch mode {
        case .bsp, .stack:
            return inward(
                frames,
                in: context.usable,
                bounds: context.sizeBounds,
                generalizing: !context.probesBeyondBounds
            )
        default:
            return frames
        }
    }

    /// `frames` with every floor-bound slot widened to the span
    /// the bound answers (`consumedWidth/Height`, the one reading
    /// of which span to emit) and moved inward. Ceilings are left
    /// alone: this pass places a floor's residue, nothing else.
    /// `generalizing` is the pass's `!probesBeyondBounds` (#1055).
    public static func inward(
        _ frames: [WindowID: CGRect],
        in region: CGRect,
        bounds: [WindowID: EffectiveSizeBound],
        generalizing: Bool
    ) -> [WindowID: CGRect] {
        guard !bounds.isEmpty else { return frames }
        var result = frames
        for (id, slot) in frames {
            guard let bound = bounds[id] else { continue }
            var frame = slot
            if let width = bound.consumedWidth(
                asking: slot.width,
                generalizing: generalizing
            ), width > slot.width {
                frame.size.width = width
                frame.origin.x = inwardOrigin(
                    slot.minX,
                    extent: width,
                    lead: region.minX,
                    trail: region.maxX
                )
            }
            if let height = bound.consumedHeight(
                asking: slot.height,
                generalizing: generalizing
            ), height > slot.height {
                frame.size.height = height
                frame.origin.y = inwardOrigin(
                    slot.minY,
                    extent: height,
                    lead: region.minY,
                    trail: region.maxY
                )
            }
            result[id] = frame
        }
        return result
    }

    /// The slot's origin pulled back until `extent` ends inside
    /// `trail`; a floor wider than the region itself keeps its
    /// leading edge at `lead`, so the edge that carries the
    /// window's controls stays reachable.
    static func inwardOrigin(
        _ origin: CGFloat,
        extent: CGFloat,
        lead: CGFloat,
        trail: CGFloat
    ) -> CGFloat {
        max(lead, min(origin, trail - extent))
    }
}
