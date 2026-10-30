import AppKit
import Testing

@testable import KiwiDeskCore

/// The hovered handles' pills as DRAWN (#2567 ▸ Ruling), read off the
/// rendered view rather than the arithmetic that sizes them: a pill
/// sits inside the rim with 1 pt clear, is never shorter than it is
/// deep, and the grown App Bar handle shows the bar's Fill past each
/// end of its pill. Rendered at 2×, the pill black on a blue Fill.
@Suite("Handle pills as drawn (#2567)", .serialized)
@MainActor
struct ShelfHandleDrawnTests {
    init() { LiquidGlassGate.override = { false } }

    private func spec(
        mark: ShelfHandleSpec.Mark = .line,
        edge: AppBarEdge = .top,
        rim: CGFloat = 3
    ) -> ShelfHandleSpec {
        let depth = ShelfHandleSpec.depth
        return ShelfHandleSpec(
            mark: mark,
            frame: edge.isHorizontal
                ? CGRect(x: 100, y: 0, width: 36, height: depth)
                : CGRect(x: 0, y: 100, width: depth, height: 36),
            edge: edge,
            fill: GlassFill(hex: "#3366CC"),
            currentInk: "#000000",
            ink: "#AAAAAA",
            emptyInk: "#555555",
            highlight: "#FF0000",
            shown: false,
            hovered: true,
            reveal: .slide,
            rimWidth: rim
        )
    }

    /// `spec` rendered as `ShelfHandle.show` sizes it, and the
    /// plate's frame in the view — which the panel's room holds.
    private func render(
        _ spec: ShelfHandleSpec
    ) -> (rep: NSBitmapImageRep, plate: CGRect)? {
        let view = ShelfHandleView()
        view.frame = CGRect(
            origin: .zero,
            size: ShelfHandle.room(of: spec).size
        )
        view.render(spec, animated: false)
        #expect(
            view.bounds.contains(view.plate.frame),
            "plate \(view.plate.frame) past the panel \(view.bounds)"
        )
        guard
            let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)
        else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)
        return (rep, view.plate.frame)
    }

    /// The span, in points, of near-black pixels along a row (`row`
    /// true) or a column through `at` points.
    private func blackSpan(
        _ rep: NSBitmapImageRep,
        row: Bool,
        at point: CGFloat
    ) -> ClosedRange<CGFloat>? {
        let scale = CGFloat(rep.pixelsWide) / rep.size.width
        let fixed = Int(point * scale)
        let count = row ? rep.pixelsWide : rep.pixelsHigh
        var hits: [Int] = []
        for index in 0..<count {
            let (x, y) = row ? (index, fixed) : (fixed, index)
            guard let colour = rep.colorAt(x: x, y: y),
                colour.alphaComponent > 0.9,
                colour.redComponent < 0.15, colour.greenComponent < 0.15,
                colour.blueComponent < 0.15
            else { continue }
            hits.append(index)
        }
        guard let first = hits.first, let last = hits.last else { return nil }
        return CGFloat(first) / scale...CGFloat(last + 1) / scale
    }

    /// The span across the edge of near-white ink — the count's —
    /// over `along`, a row range on a side edge.
    private func inkAcross(
        _ rep: NSBitmapImageRep,
        along: ClosedRange<CGFloat>
    ) -> ClosedRange<CGFloat>? {
        let scale = CGFloat(rep.pixelsWide) / rep.size.width
        var low = Int.max
        var high = Int.min
        for y in Int(along.lowerBound * scale)..<Int(along.upperBound * scale)
        {
            for x in 0..<rep.pixelsWide {
                guard let colour = rep.colorAt(x: x, y: y),
                    colour.alphaComponent > 0.9,
                    colour.redComponent > 0.85, colour.greenComponent > 0.85,
                    colour.blueComponent > 0.85
                else { continue }
                low = min(low, x)
                high = max(high, x)
            }
        }
        guard low <= high else { return nil }
        return CGFloat(low) / scale...CGFloat(high + 1) / scale
    }

    @Test("The App Bar count pill shows Fill at both ends, inside the rim")
    func countPillAsDrawn() throws {
        for windows in [7, 128] {
            var top = spec()
            top.count = ShelfHandleSpec.count(
                windows,
                font: NSFont.systemFont(ofSize: 12),
                edge: .top,
                pillDepth: top.pillDepth
            )
            let (rep, plate) = try #require(render(top))
            let along = try #require(
                blackSpan(rep, row: true, at: plate.midY)
            )
            #expect(
                along.lowerBound - plate.minX >= ShelfHandleSpec.fillRun - 1
            )
            #expect(
                plate.maxX - along.upperBound >= ShelfHandleSpec.fillRun - 1
            )
            // Through the pill's straight run, past its rounded end.
            let across = try #require(
                blackSpan(
                    rep,
                    row: false,
                    at: along.lowerBound + top.pillDepth / 2
                )
            )
            #expect(across.lowerBound - plate.minY >= top.rimWidth + 0.5)
            #expect(plate.maxY - across.upperBound >= top.rimWidth + 0.5)
        }
    }

    @Test("A side edge's count pill stands inside the widened rim")
    func sidePillAsDrawn() throws {
        var side = spec(edge: .left)
        side.count = ShelfHandleSpec.count(
            42,
            font: NSFont.systemFont(ofSize: 12),
            edge: .left,
            pillDepth: side.pillDepth
        )
        let (rep, plate) = try #require(render(side))
        let along = try #require(blackSpan(rep, row: false, at: plate.midX))
        #expect(
            along.lowerBound - plate.minY >= ShelfHandleSpec.fillRun - 1
        )
        #expect(
            plate.maxY - along.upperBound >= ShelfHandleSpec.fillRun - 1
        )
        let pill = side.pill(of: try #require(side.count))
        let across = try #require(
            blackSpan(
                rep,
                row: true,
                at: along.lowerBound + min(pill.along, pill.across) / 2
            )
        )
        #expect(across.lowerBound - plate.minX >= side.rimWidth + 0.5)
        #expect(plate.maxX - across.upperBound >= side.rimWidth + 0.5)
        // The number and symbol stand inside the pill across it.
        let ink = try #require(inkAcross(rep, along: along))
        #expect(ink.lowerBound >= across.lowerBound)
        #expect(ink.upperBound <= across.upperBound)
    }

    @Test("A narrow Space name's pill is round, never an upright oval")
    func spacePillAsDrawn() throws {
        var dots = spec(
            mark: .dots([.init(current: true, occupied: true)]),
            rim: 1
        )
        dots.label = ShelfHandleSpec.label(
            .text("1", tinted: true),
            font: NSFont.systemFont(ofSize: 12)
        )
        let (rep, plate) = try #require(render(dots))
        let along = try #require(blackSpan(rep, row: true, at: plate.midY))
        let across = try #require(
            blackSpan(
                rep,
                row: false,
                at: (along.lowerBound + along.upperBound) / 2
            )
        )
        let length = along.upperBound - along.lowerBound
        let depth = across.upperBound - across.lowerBound
        #expect(length >= depth - 1, "pill \(length) × \(depth)")
        #expect(across.lowerBound - plate.minY >= dots.rimWidth + 0.5)
    }
}
