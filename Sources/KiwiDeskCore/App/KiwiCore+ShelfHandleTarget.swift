import AppKit

/// Where an Auto bar's handle and approach sit (#3349): the handle
/// along the bar's run against the screen side of the shelf's area,
/// the approach about it. Pure over the pass's plan.
extension KiwiCore.HidingShelves {
    /// The screen side of the shelf's area on `edge` — `strip`'s
    /// outer side less the outer margin — on the edge's axis, AX.
    static func side(
        of strip: CGRect,
        edge: AppBarEdge,
        shelf: KiwiShelf
    ) -> CGFloat {
        switch edge {
        case .top: return strip.minY - shelf.outerMargin
        case .bottom: return strip.maxY + shelf.outerMargin
        case .left: return strip.minX - shelf.outerMargin
        case .right: return strip.maxX + shelf.outerMargin
        }
    }

    /// The bar the pocket's slot sits beside (#2678): the nearer of
    /// the two by slot middle.
    static func pocketBar(of arrangement: ShelfArrangement) -> ShelfBar? {
        guard let pocket = arrangement.pocket else { return nil }
        var nearest = CGFloat.greatestFiniteMagnitude
        var bar: ShelfBar?
        for candidate in [ShelfBar.space, .app] {
            let slot =
                candidate == .space ? arrangement.space : arrangement.app
            guard let slot else { continue }
            let distance = abs(slot.offset + slot.length / 2 - pocket.offset)
            if distance < nearest {
                nearest = distance
                bar = candidate
            }
        }
        return bar
    }

    /// The revealer's target for `spec`'s handle, Cocoa: its
    /// approach along the handle, reaching `outward` past the
    /// screen side and `ShelfReveal.approachReach` in — over a
    /// maximized window (`maximized`) only to the thickened handle,
    /// so a pause on its tab bar or toolbar drops no bar over them
    /// (#3346) — cut at the handle's end where a sibling's approach
    /// meets it (`cut`), so a point opens one bar.
    @MainActor static func target(
        _ spec: ShelfHandleSpec,
        strip: CGRect,
        screen: CGRect,
        section: CGRect?,
        outward: CGFloat,
        maximized: Bool = false,
        cut: (lead: Bool, trail: Bool)
    ) -> ShelfRevealer.Target {
        let primary = GeometryUtils.primaryHeight
        let handle = GeometryUtils.flip(spec.frame, primaryHeight: primary)
        let grown = GeometryUtils.flip(spec.grown, primaryHeight: primary)
        let inset = ShelfHandleSpec.inset
        let side: CGFloat =
            switch spec.edge {
            case .top: handle.maxY + inset
            case .bottom: handle.minY - inset
            case .left: handle.minX - inset
            case .right: handle.maxX + inset
            }
        var approach = ShelfReveal.approach(
            along: handle,
            edge: spec.edge,
            side: side,
            outward: outward,
            inward: maximized
                ? inset + ShelfHandleSpec.depth
                    + 2 * ShelfHandleSpec.hoverGrowth
                : ShelfReveal.approachReach
        )
        // AX runs top to bottom along a side edge, Cocoa bottom to
        // top: the leading end is the top there.
        let reach = ShelfReveal.alongReach
        let low = spec.horizontal ? cut.lead : cut.trail
        let high = spec.horizontal ? cut.trail : cut.lead
        let cuts = CGFloat((low ? 1 : 0) + (high ? 1 : 0)) * reach
        let shift = low ? reach : 0
        if spec.horizontal {
            approach.origin.x += shift
            approach.size.width -= cuts
        } else {
            approach.origin.y += shift
            approach.size.height -= cuts
        }
        let touch = ShelfReveal.pushReach
        let flush: Bool =
            switch spec.edge {
            case .top: screen.maxY - side <= touch
            case .bottom: side - screen.minY <= touch
            case .left: side - screen.minX <= touch
            case .right: screen.maxX - side <= touch
            }
        return ShelfRevealer.Target(
            edge: spec.edge,
            strip: strip,
            screen: screen,
            approach: approach,
            handle: grown,
            flush: flush,
            section: section
        )
    }
}
