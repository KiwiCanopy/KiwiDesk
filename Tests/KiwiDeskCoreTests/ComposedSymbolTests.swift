import AppKit
import Testing

@testable import KiwiDeskCore

/// A `ComposedSymbol` draws through `SymbolImage.named` at its base's
/// size and template flag, with its badge inside the base and the
/// base cleared around it (#3284). Main-actor spend: none; each case
/// draws a few small bitmaps.
@Suite("Composed symbols (#3284)")
struct ComposedSymbolTests {
    private let config = NSImage.SymbolConfiguration(
        pointSize: 22,
        weight: .regular
    )

    @Test("every composed glyph resolves at its base's size")
    func composedResolves() throws {
        for symbol in ComposedSymbol.all {
            #expect(ComposedSymbol(name: symbol.name) == symbol)
            let base = try #require(
                SymbolImage.named(symbol.base, configuration: config)
            )
            let image = try #require(
                SymbolImage.named(symbol.name, configuration: config),
                "\(symbol.name) does not resolve"
            )
            #expect(image.size == base.size, "\(symbol.name)")
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

    @Test("the badge sits inside the base, in its corner")
    func badgeInsideTheBase() {
        let size = NSSize(width: 30, height: 20)
        let badge = NSSize(width: 10, height: 12)
        let low = SymbolImage.badgeRect(
            .bottomTrailing,
            badge: badge,
            in: size
        )
        let high = SymbolImage.badgeRect(.topTrailing, badge: badge, in: size)
        let bounds = NSRect(origin: .zero, size: size)
        #expect(bounds.contains(low) && bounds.contains(high))
        #expect(low.maxX == size.width && high.maxX == size.width)
        #expect(low.minY == 0 && high.maxY == size.height)
        #expect(
            max(low.width, low.height)
                == max(size.width, size.height) * ComposedSymbol.badgeShare
        )
    }

    @Test("the base is cleared around the badge")
    func haloClearsTheBase() throws {
        // `rectangle.stack`'s outline runs under the grid badge's
        // corner, where the halo must leave the base transparent.
        let symbol = ComposedSymbol.desktopOverview
        let plain = try #require(
            bitmap(SymbolImage.named(symbol.base, configuration: config))
        )
        let composed = try #require(
            bitmap(SymbolImage.named(symbol.name, configuration: config))
        )
        #expect(inked(plain) > inked(composed, outsideBadgeOf: symbol))
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

    /// Inked pixels, leaving out the badge's own rect where `symbol`
    /// is given, so only the base's ink is counted.
    private func inked(
        _ rep: NSBitmapImageRep,
        outsideBadgeOf symbol: ComposedSymbol? = nil
    ) -> Int {
        var skip = NSRect.zero
        if let symbol,
            let badge = SymbolImage.named(symbol.badge, configuration: config)
        {
            let rect = SymbolImage.badgeRect(
                symbol.corner,
                badge: badge.size,
                in: rep.size
            )
            // Bitmap rows run top down; the rect is y-up.
            skip = NSRect(
                x: rect.minX * 2,
                y: (rep.size.height - rect.maxY) * 2,
                width: rect.width * 2,
                height: rect.height * 2
            )
        }
        var count = 0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide
            where !skip.contains(NSPoint(x: x, y: y)) {
                if (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 {
                    count += 1
                }
            }
        }
        return count
    }
}
