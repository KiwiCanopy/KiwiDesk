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

    /// The revealer's target for `spec`'s handle, its area's
    /// screen side at AX `side` (`side(of:edge:shelf:)`, the one
    /// the handle's frame took): an approach from
    /// `ShelfReveal.overshoot` past that side to
    /// `ShelfReveal.approachReach` in — over a maximized window
    /// (`maximized`) only to its hover band, so a pause on its
    /// toolbar drops no bar over it for long (#3346) — cut where a
    /// sibling's approach meets it (`cut`).
    @MainActor static func target(
        _ spec: ShelfHandleSpec,
        side: CGFloat,
        strip: CGRect,
        screen: CGRect,
        beyond: Bool,
        section: CGRect?,
        maximized: Bool = false,
        cut: (lead: Bool, trail: Bool)
    ) -> ShelfRevealer.Target {
        let primary = GeometryUtils.primaryHeight
        let flip = { GeometryUtils.flip($0, primaryHeight: primary) }
        return .along(
            flip(spec.frame),
            edge: spec.edge,
            side: spec.horizontal ? primary - side : side,
            strip: strip,
            screen: screen,
            beyond: beyond,
            handle: flip(spec.hoverBand),
            section: section,
            inward: maximized
                ? ShelfHandleSpec.inset
                    + (spec.horizontal
                        ? spec.hoverBand.height : spec.hoverBand.width)
                : ShelfReveal.approachReach,
            cut: cut
        )
    }

    /// Whether a screen in `screens` continues past `edge` of
    /// `frame` along `span` — a bar's run — Cocoa: the edge is a
    /// crossing there, never a stop. A neighbour beside only part
    /// of the edge leaves a run past it free.
    static func continues(
        _ edge: AppBarEdge,
        of frame: CGRect,
        along span: CGRect,
        among screens: [CGRect]
    ) -> Bool {
        screens.contains { other in
            guard other != frame else { return false }
            let along =
                edge.isHorizontal
                ? other.minX < span.maxX && other.maxX > span.minX
                : other.minY < span.maxY && other.maxY > span.minY
            guard along else { return false }
            switch edge {
            case .top: return abs(other.minY - frame.maxY) < 1
            case .bottom: return abs(other.maxY - frame.minY) < 1
            case .left: return abs(other.maxX - frame.minX) < 1
            case .right: return abs(other.minX - frame.maxX) < 1
            }
        }
    }
}
