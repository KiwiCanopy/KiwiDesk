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

    /// The dark appearance's label ink alpha, which every strength
    /// scales (#3514).
    private var own: CGFloat {
        ShelfHandleSpec.labelInk(
            in: NSAppearance(named: .darkAqua)!
        ).alphaComponent
    }

    /// A pixel's light, premultiplied: the white label ink's share
    /// in dark mode, where the hairline is black and adds none. Rest
    /// and fill differ in lightness, not alpha (#3514).
    private func light(_ color: NSColor?) -> CGFloat {
        guard let c = color?.usingColorSpace(.sRGB) else { return 0 }
        return c.redComponent * c.alphaComponent
    }

    /// The resting core's light: the white ink mixed `restMix`
    /// toward black, at its own alpha.
    private var restLight: CGFloat { (1 - ShelfHandleSpec.restMix) * own }
    /// The filled core's light: the ink itself.
    private var fullLight: CGFloat { own }

    /// The most opaque pixel across the middle of `rep`.
    private func peak(_ rep: NSBitmapImageRep, horizontal: Bool) -> CGFloat {
        let count = horizontal ? rep.pixelsHigh : rep.pixelsWide
        return (0..<count).map { step in
            let x = horizontal ? rep.pixelsWide / 2 : step
            let y = horizontal ? step : rep.pixelsHigh / 2
            return light(rep.colorAt(x: x, y: y))
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
            frame: ShelfHandleSpec.frame(
                along: run,
                edge: edge,
                side: 0,
                depth: 3
            ),
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
        // The core's resting ink, over the hairline capsule, reaches
        // the pixels; within 0.1, still far from the fill's light.
        #expect(
            abs(
                peak(rep, horizontal: edge.isHorizontal) - restLight
            ) < 0.1,
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
        // The end's middle shows at least the hairline (#3514).
        #expect(
            endMiddle > 0.8 * ShelfHandleSpec.hairlineStrength,
            "\(edge): end \(endMiddle)"
        )
        #expect(corner < 0.8 * endMiddle, "\(edge): corner \(corner)")
        // The hairline rings the core: the outermost row at mid-length
        // shows less ink than the middle.
        let rim = light(
            edge.isHorizontal
                ? rep.colorAt(x: rep.pixelsWide / 2, y: 0)
                : rep.colorAt(x: 0, y: rep.pixelsHigh / 2)
        )
        let middle = peak(rep, horizontal: edge.isHorizontal)
        #expect(rim < middle - 0.08, "\(edge): rim \(rim)")
        // The core is a capsule too, and clips the progress fill.
        let core = try #require(view.core.layer)
        #expect(
            core.cornerRadius
                == ShelfHandleSpec.radius(of: view.core.frame)
        )
        #expect(core.masksToBounds)
    }

    @Test("the pocket's tab brightens in place on hover")
    func tabBrightens() throws {
        let size = CGSize(
            width: 40,
            height: PocketHandleView.restDepth(of: KiwiShelf())
        )
        // The tab's core row, mid-tab, in a draw `hovered` or not, of
        // an empty pocket unless `holds` (#3384).
        let core = {
            (hovered: Bool, out: Bool, holds: Bool) throws -> CGFloat in
            let view = PocketHandleView(
                frame: CGRect(origin: .zero, size: size)
            )
            view.appearance = NSAppearance(named: .darkAqua)
            view.holds = holds
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
            // The core's middle row, whole at 1x and 2x alike.
            let row = Int((size.height - 1.5) * scale)
            return self.light(rep.colorAt(x: rep.pixelsWide / 2, y: row))
        }
        // The tab is a capsule: its end's corner is emptier than its
        // end's middle, which a square end draws alike.
        let view = PocketHandleView(frame: CGRect(origin: .zero, size: size))
        view.appearance = NSAppearance(named: .darkAqua)
        view.wear(
            KiwiShelf(),
            markHex: "#FF0000",
            edge: .bottom,
            kiwisOut: false
        )
        let rep = try #require(
            view.bitmapImageRepForCachingDisplay(in: view.bounds)
        )
        view.cacheDisplay(in: view.bounds, to: rep)
        let scale = CGFloat(rep.pixelsHigh) / size.height
        let end = Int((size.width - PocketHandleView.tabLength) / 2 * scale)
        let alpha = { (y: Int) in
            rep.colorAt(x: end, y: y)?.alphaComponent ?? 0
        }
        let endMiddle = alpha(Int((size.height - 1.5) * scale))
        let corner = alpha(rep.pixelsHigh - 1)
        #expect(
            endMiddle > 0.8 * ShelfHandleSpec.hairlineStrength,
            "tab end \(endMiddle)"
        )
        #expect(corner < 0.8 * endMiddle, "tab corner \(corner)")
        let rest = restLight
        let full = fullLight
        #expect(abs(try core(false, false, false) - rest) < 0.05)
        #expect(abs(try core(true, false, false) - full) < 0.05)
        // Holding something, the tab rests at full strength (#3384).
        #expect(abs(try core(false, false, true) - full) < 0.05)
        // Risen, an empty tab stays at rest: Core hands no hover then
        // (`PocketApproachTests` ▸ `hoverLightsInPlace`).
        #expect(abs(try core(false, true, false) - rest) < 0.05)
    }

    @Test(
        "the tab's countdown fill lands on its drawn core",
        arguments: [AppBarEdge.top, .left]
    )
    func tabFillLandsOnTheCore(edge: AppBarEdge) throws {
        pinRevealLength()
        let along: CGFloat = 40
        let across = PocketHandleView.restDepth(of: KiwiShelf())
        let size =
            edge.isHorizontal
            ? CGSize(width: along, height: across)
            : CGSize(width: across, height: along)
        let view = PocketHandleView(frame: CGRect(origin: .zero, size: size))
        view.appearance = NSAppearance(named: .darkAqua)
        let start = Date(timeIntervalSince1970: 1_000)
        view.wear(
            KiwiShelf(),
            markHex: "#FF0000",
            edge: edge,
            kiwisOut: true,
            fill: .init(
                origin: 0.5,
                started: start,
                until: start.addingTimeInterval(ShelfReveal.dwellDelay)
            )
        )
        view.layoutSubtreeIfNeeded()
        let rep = try pixels(of: view)
        let scale = CGFloat(rep.pixelsWide) / size.width
        let core = view.tabCoreFrame()
        let lit = light(
            rep.colorAt(x: Int(core.midX * scale), y: Int(core.midY * scale))
        )
        // The fill over the resting core, never the core alone, which
        // a fill on the wrong side would leave.
        let filled = fullLight + (1 - own) * restLight
        #expect(abs(lit - filled) < 0.05, "\(edge): \(lit)")
    }
}
