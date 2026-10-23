import AppKit

/// The hidden App Bar mark's count pill (#2567 ▸ Ruling), drawn
/// only while the mark is grown: centred on the plate, in the Space
/// mark's own pill ink — the active item colour, the empty one at
/// 0 — with the number on its figures band and the glyph tinted
/// against the pill, laid out as one unit.
extension ShelfIndicatorDots {
    func drawCount(_ spec: ShelfIndicatorSpec) {
        guard spec.hovered, let count = spec.count else { return }
        let size = spec.pill(of: count)
        let pill =
            spec.horizontal
            ? CGRect(
                x: mark.midX - size.along / 2,
                y: mark.midY - size.across / 2,
                width: size.along,
                height: size.across
            )
            : CGRect(
                x: mark.midX - size.across / 2,
                y: mark.midY - size.along / 2,
                width: size.across,
                height: size.along
            )
        let fill = NSColor(
            kiwiHex: count.windows == 0 ? spec.emptyInk : spec.currentInk
        )
        fill.setFill()
        let radius = min(pill.width, pill.height) / 2
        NSBezierPath(roundedRect: pill, xRadius: radius, yRadius: radius)
            .fill()
        let ink = fill.contrastingGlyph
        let content = count.content
        var lead =
            (spec.horizontal ? pill.midX : pill.midY) - content.along / 2
        if count.showsNumber {
            let middle =
                spec.horizontal
                ? CGPoint(x: lead + count.number.width / 2, y: pill.midY)
                : CGPoint(x: pill.midX, y: lead + count.number.height / 2)
            drawNumber(count, centredOn: middle, ink: ink)
            lead +=
                (spec.horizontal ? count.number.width : count.number.height)
                + ShelfIndicatorSpec.countGap
        }
        let origin =
            spec.horizontal
            ? CGPoint(x: lead, y: pill.midY - count.glyph.height / 2)
            : CGPoint(x: pill.midX - count.glyph.width / 2, y: lead)
        drawGlyph(count, at: origin, ink: ink)
    }

    /// The number's ink centred on `middle`, its baseline the
    /// figures band's (`BarTextGlyph`).
    private func drawNumber(
        _ count: ShelfIndicatorSpec.Count,
        centredOn middle: CGPoint,
        ink: NSColor
    ) {
        let text = "\(count.windows)"
        let metrics = BarTextGlyph.metrics(text, font: count.font)
        (text as NSString).draw(
            at: CGPoint(
                x: metrics.originX(
                    centringInkOn: middle.x,
                    frameWidth: metrics.advance
                ),
                y: BarTextGlyph.lineTop(
                    centredOn: middle.y,
                    band: .figures,
                    font: count.font
                )
            ),
            withAttributes: [.font: count.font, .foregroundColor: ink]
        )
    }

    /// The count's glyph at its measured size, tinted `ink`.
    private func drawGlyph(
        _ count: ShelfIndicatorSpec.Count,
        at origin: CGPoint,
        ink: NSColor
    ) {
        guard
            let image = ShelfIndicatorSpec.countSymbol(
                count.glyphName,
                size: count.glyphPoint
            )
        else { return }
        let tinted = NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect)
            ink.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        tinted.draw(in: CGRect(origin: origin, size: count.glyph))
    }
}
