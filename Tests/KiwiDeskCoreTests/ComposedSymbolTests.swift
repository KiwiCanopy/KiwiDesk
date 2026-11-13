import AppKit
import Testing

@testable import KiwiDeskCore

/// A `ComposedSymbol` draws through `SymbolImage.named` on a canvas
/// holding its base and its overhanging badge, keeping the base's
/// template flag, with the base cleared in a ring around the badge
/// (#3284). Main-actor spend: none; each case draws a few small
/// bitmaps.
@Suite("Composed symbols (#3284)")
struct ComposedSymbolTests {
    private let style = SymbolImage.Style(pointSize: 22)

    @Test("every composed glyph resolves on its layout's canvas")
    func composedResolves() throws {
        for symbol in ComposedSymbol.all {
            #expect(ComposedSymbol(name: symbol.name) == symbol)
            let base = try #require(
                SymbolImage.named(symbol.base, style: style)
            )
            let image = try #require(
                SymbolImage.named(symbol.name, style: style),
                "\(symbol.name) does not resolve"
            )
            let canvas = symbol.layout(in: base.size, flipped: false)
                .canvas
            #expect(image.size == canvas.size, "\(symbol.name)")
            #expect(image.isTemplate == base.isTemplate, "\(symbol.name)")
        }
        #expect(Set(ComposedSymbol.all.map(\.name)).count == 3)
    }

    @Test("a plain name is the SF Symbol of that name")
    func plainPassesThrough() throws {
        #expect(ComposedSymbol(name: "pin.fill") == nil)
        let plain = try #require(SymbolImage.named("pin.fill"))
        #expect(plain.isTemplate)
        #expect(SymbolImage.named("kiwi.no.such.glyph") == nil)
    }

    @Test("the badge square overhangs its corner, the ring around it")
    func layoutPlacesTheBadge() {
        let size = CGSize(width: 30, height: 20)
        let base = CGRect(origin: .zero, size: size)
        for symbol in ComposedSymbol.all {
            let up = symbol.layout(in: size, flipped: false)
            let down = symbol.layout(in: size, flipped: true)
            let side = 30 * ComposedSymbol.badgeShare
            #expect(up.badge.width == side && up.badge.height == side)
            #expect(up.badge.maxX == 30 + side * symbol.overhang.dx)
            let low = symbol.corner == .bottomTrailing
            let reach = side * symbol.overhang.dy
            #expect(
                low ? up.badge.minY == -reach : up.badge.maxY == 20 + reach
            )
            #expect(up.canvas == base.union(up.badge), "\(symbol.name)")
            // The ring holds the square and the gap, and the cleared
            // area reaches past the base in the corner's directions.
            let gap = side * ComposedSymbol.gapShare
            let ring = up.badge.insetBy(dx: -gap, dy: -gap)
            #expect(up.knockout.contains(ring), "\(symbol.name)")
            #expect(up.knockout.maxX > base.maxX)
            #expect(low ? up.knockout.minY < 0 : up.knockout.maxY > 20)
            // Flipped is the same layout, mirrored on y.
            #expect(down.badge.minY == 20 - up.badge.maxY)
            #expect(down.knockout.minY == 20 - up.knockout.maxY)
            #expect(down.canvas.minY == 20 - up.canvas.maxY)
        }
    }

    @Test("the badge draws heavier than the base")
    func badgeIsHeavier() {
        let base = SymbolImage.Style(weight: .semibold)
        #expect(base.badge.weight == .heavy)
        #expect(SymbolImage.Style(weight: .black).badge.weight == .black)
    }

    @Test("the base is cleared in the ring around the badge")
    func ringClearsTheBase() throws {
        // `rectangle.stack`'s outline runs through the ring around the
        // grid badge: inked in the plain base, cleared when composed.
        let symbol = ComposedSymbol.desktopOverview
        let plainImage = try #require(
            SymbolImage.named(symbol.base, style: style)
        )
        let plain = try #require(bitmap(plainImage))
        let composed = try #require(
            bitmap(SymbolImage.named(symbol.name, style: style))
        )
        let layout = symbol.layout(in: plainImage.size, flipped: true)
        let inPlain = ringInk(plain, layout, offset: .zero)
        let inComposed = ringInk(
            composed,
            layout,
            offset: CGPoint(x: layout.canvas.minX, y: layout.canvas.minY)
        )
        #expect(inPlain > 0, "the ring holds none of the base's ink")
        #expect(inComposed == 0)
    }

    @Test("sticky wears the pin family, display sticky composed")
    func stickyIsThePinFamily() {
        #expect(StickyStyle.symbolName == "pin.fill")
        let display = ComposedSymbol(name: StickyStyle.displaySymbolName)
        #expect(display?.base == StickyStyle.symbolName)
    }

    private func bitmap(_ image: NSImage?) -> NSBitmapImageRep? {
        guard let image else { return nil }
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(image.size.width * 2),
            pixelsHigh: Int(image.size.height * 2),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        guard let rep else { return nil }
        rep.size = image.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    /// Inked pixels inside the ring — the knockout less the badge
    /// square, both inset half a pixel so antialiasing at their edges
    /// is not counted — read in base coordinates, y down, `offset` being
    /// where the bitmap's origin sits in them.
    private func ringInk(
        _ rep: NSBitmapImageRep,
        _ layout: ComposedSymbol.Layout,
        offset: CGPoint
    ) -> Int {
        let ring = layout.knockout.insetBy(dx: 0.25, dy: 0.25)
        let square = layout.badge.insetBy(dx: -0.25, dy: -0.25)
        var count = 0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                let point = CGPoint(
                    x: CGFloat(x) / 2 + offset.x,
                    y: CGFloat(y) / 2 + offset.y
                )
                guard ring.contains(point), !square.contains(point)
                else { continue }
                if (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 {
                    count += 1
                }
            }
        }
        return count
    }
}
