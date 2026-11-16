import AppKit
import Testing

@testable import KiwiDeskCore

/// A handle draws (#3366): its view, drawn to pixels, carries the
/// core's ink on every edge as a capsule, and the pocket's tab
/// brightens in place on hover. Frames and colours alone read right
/// while the body that holds them hung under no view, so these read
/// pixels through the view that draws. Main-actor spend: a few
/// unwindowed renders.
@Suite("Shelf handle draws (#3366)", .serialized)
@MainActor
struct ShelfHandleDrawTests {
    /// `view` drawn through AppKit, its layer-backed subviews
    /// included — the path the panel's own display takes.
    private func pixels(of view: NSView) throws -> NSBitmapImageRep {
        let rep = try #require(
            view.bitmapImageRepForCachingDisplay(in: view.bounds)
        )
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep
    }

    /// A core of `strength` drawn over the hairline capsule.
    private func over(_ strength: CGFloat) -> CGFloat {
        strength + ShelfHandleSpec.hairlineStrength * (1 - strength)
    }

    /// The most opaque pixel across the middle of `rep`.
    private func peak(_ rep: NSBitmapImageRep, horizontal: Bool) -> CGFloat {
        let count = horizontal ? rep.pixelsHigh : rep.pixelsWide
        return (0..<count).map { step in
            let x = horizontal ? rep.pixelsWide / 2 : step
            let y = horizontal ? step : rep.pixelsHigh / 2
            return rep.colorAt(x: x, y: y)?.alphaComponent ?? 0
        }.max() ?? 0
    }

    @Test(
        "the handle's view draws its core on every edge",
        arguments: AppBarEdge.allCases
    )
    func handleDraws(edge: AppBarEdge) throws {
        pinRevealLength()
        let run =
            edge.isHorizontal
            ? CGRect(x: 100, y: 0, width: 400, height: 30)
            : CGRect(x: 0, y: 100, width: 30, height: 400)
        let spec = ShelfHandleSpec(
            frame: ShelfHandleSpec.frame(along: run, edge: edge, side: 0),
            edge: edge,
            shown: false,
            reveal: .slide
        )
        let handle = ShelfHandle()
        handle.ordersPanel = false
        handle.show(spec)
        let view = handle.view
        view.appearance = NSAppearance(named: .darkAqua)
        view.render(spec, animated: false)
        let rep = try pixels(of: view)
        // The core's label ink at its rest strength, over the
        // hairline capsule, reaches the pixels.
        #expect(
            abs(
                peak(rep, horizontal: edge.isHorizontal)
                    - over(ShelfHandleSpec.restStrength)
            ) < 0.05,
            "\(edge)"
        )
        // A capsule: its end rounds away from the corner, where a
        // square end draws the corner as full as the end's middle.
        // A ratio, so it holds at 1x and 2x alike.
        let alpha = { (x: Int, y: Int) in
            rep.colorAt(x: x, y: y)?.alphaComponent ?? 0
        }
        let endMiddle =
            edge.isHorizontal
            ? alpha(0, rep.pixelsHigh / 2) : alpha(rep.pixelsWide / 2, 0)
        let corner = alpha(0, 0)
        #expect(endMiddle > 0.3, "\(edge): end \(endMiddle)")
        #expect(corner < 0.8 * endMiddle, "\(edge): corner \(corner)")
    }

    @Test("the pocket's tab brightens in place on hover")
    func tabBrightens() throws {
        let size = CGSize(width: 40, height: PocketHandleView.restDepth)
        // The tab's core row, mid-tab, in a draw `hovered` or not.
        let core = { (hovered: Bool, out: Bool) throws -> CGFloat in
            let view = PocketHandleView(
                frame: CGRect(origin: .zero, size: size)
            )
            view.appearance = NSAppearance(named: .darkAqua)
            view.wear(
                KiwiShelf(),
                markHex: "#FF0000",
                edge: .bottom,
                kiwisOut: out,
                hovered: hovered
            )
            let rep = try #require(
                view.bitmapImageRepForCachingDisplay(in: view.bounds)
            )
            view.cacheDisplay(in: view.bounds, to: rep)
            let scale = CGFloat(rep.pixelsHigh) / size.height
            let row = rep.pixelsHigh - Int(1.5 * scale)
            return rep.colorAt(x: rep.pixelsWide / 2, y: row)?
                .alphaComponent ?? 0
        }
        let rest = over(ShelfHandleSpec.restStrength)
        #expect(abs(try core(false, false) - rest) < 0.05)
        #expect(
            abs(try core(true, false) - over(ShelfHandleSpec.fillStrength))
                < 0.05
        )
        // Risen, the kiwis are out and hover lights nothing.
        #expect(abs(try core(true, true) - rest) < 0.05)
    }
}
