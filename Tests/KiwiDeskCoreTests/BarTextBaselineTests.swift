import AppKit
import Testing

@testable import KiwiDeskCore

/// Bar text sets one baseline per font, its cap height centred
/// on the item (#1707). Apple Chancery is the widest input: an
/// ascent far above its caps, so the line box lifts it, and
/// old-style figures, so per-string ink centring gives a 1 and
/// an H different baselines. The baseline is read off the ink's
/// bottom (an H and a 1 both sit on it) and the cap band is the
/// font's own `capHeight` above it: Chancery's swash H rises past
/// its caps, so the ink's middle is not the measurement.
@Suite("Bar text centres its cap band on one baseline")
@MainActor
struct BarTextBaselineTests {
    static let family = "Apple Chancery"

    init() { LiquidGlassGate.override = { false } }

    /// The rows of `field`'s render that carry ink, in points
    /// down from its frame's top edge.
    static func inkRows(
        of field: NSTextField
    ) -> ClosedRange<CGFloat>? {
        guard
            let rep = field.bitmapImageRepForCachingDisplay(
                in: field.bounds
            )
        else { return nil }
        field.cacheDisplay(in: field.bounds, to: rep)
        let scale = CGFloat(rep.pixelsHigh) / field.bounds.height
        let inked = (0..<rep.pixelsHigh).filter { y in
            (0..<rep.pixelsWide).contains { x in
                (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05
            }
        }
        guard let first = inked.first, let last = inked.last else {
            return nil
        }
        return (CGFloat(first) / scale)...(CGFloat(last + 1) / scale)
    }

    /// The identifier's ink rows in the item's own (flipped)
    /// coordinates, and the item's middle.
    static func identifier(
        _ text: String,
        depth: CGFloat,
        fontSize: CGFloat
    ) throws -> (
        ink: ClosedRange<CGFloat>, mid: CGFloat, cap: CGFloat
    ) {
        var style = SpaceBarLook()
        style.fontFamily = family
        style.fontSize = fontSize
        let length = SpaceBarItemView.autoLength(
            appCount: 0,
            contentDepth: depth,
            glyphGap: 0
        )
        let view = SpaceBarItemView(
            frame: CGRect(x: 0, y: 0, width: length, height: depth)
        )
        view.configure(
            identity: .space(SpaceID(text)),
            spaceGlyph: .text(text, tinted: true),
            apps: [],
            active: true,
            horizontal: true,
            style: style,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
        view.layout()
        let field = view.identifierLabel
        let rows = try #require(inkRows(of: field), "\(text): no ink")
        let top = field.frame.minY
        return (
            (top + rows.lowerBound)...(top + rows.upperBound),
            view.bounds.midY,
            try #require(field.font).capHeight
        )
    }

    @Test(
        "an identifier's caps are centred and share one baseline",
        arguments: [
            (KiwiShelf.minThickness, CGFloat(14)),
            (CGFloat(44), CGFloat(40)),
        ]
    )
    func identifierBaseline(depth: CGFloat, fontSize: CGFloat) throws {
        try #require(BarFont.isInstalled(Self.family))
        let cap = try Self.identifier(
            "H",
            depth: depth,
            fontSize: fontSize
        )
        let one = try Self.identifier(
            "1",
            depth: depth,
            fontSize: fontSize
        )
        let capMid = cap.ink.upperBound - cap.cap / 2
        #expect(
            abs(capMid - cap.mid) <= 1,
            "cap band middle \(capMid) vs item middle \(cap.mid)"
        )
        #expect(
            abs(cap.ink.upperBound - one.ink.upperBound) <= 1,
            "H sits on \(cap.ink.upperBound), 1 on \(one.ink.upperBound)"
        )
    }

    @Test("an App Bar title centres its caps on the item")
    func appBarTitle() throws {
        try #require(BarFont.isInstalled(Self.family))
        var shelf = KiwiShelf()
        shelf.fontFamily = Self.family
        shelf.fontSize = 22
        let view = AppBarItemView(
            frame: NSRect(x: 0, y: 0, width: 200, height: 40)
        )
        view.configure(
            id: WindowID(1),
            text: "HH",
            icon: nil,
            glyph: nil,
            count: 1,
            active: true,
            horizontal: true,
            style: AppBarLook(shelf: shelf)
        )
        view.layout()
        let field = view.label
        let rows = try #require(Self.inkRows(of: field))
        // Whole: a clipped title's ink starts on the frame's edge.
        #expect(rows.lowerBound > 0, "title clipped: \(rows)")
        let cap = try #require(field.font).capHeight
        let mid = field.frame.minY + rows.upperBound - cap / 2
        #expect(
            abs(mid - view.bounds.midY) <= 1,
            "title ink \(rows) at \(field.frame) vs \(view.bounds)"
        )
    }
}
