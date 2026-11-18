import AppKit
import QuartzCore
import Testing

@testable import KiwiDeskCore

/// A handle's look and its approach fill (#3360, #3361): at the
/// default thickness a 2 pt core capsule on a neutral 3 pt capsule,
/// flush on the edge (the thickness itself: `HandleThicknessTests`),
/// and a fill that runs out from its start along the core alone,
/// plays under Reduce Motion and drops under KiwiDesk's Off. What
/// the animator then draws is the device's. Main-actor spend: a few
/// unwindowed views.
@Suite("Shelf handle fill (#3360)", .serialized)
@MainActor
struct ShelfHandleFillTests {
    private static let frame = CGRect(x: 100, y: 0, width: 400, height: 3)

    private func spec(
        _ fill: ShelfHandleSpec.Fill? = nil,
        edge: AppBarEdge = .top
    ) -> ShelfHandleSpec {
        let frame =
            edge.isHorizontal
            ? Self.frame : CGRect(x: 0, y: 100, width: 3, height: 400)
        return ShelfHandleSpec(
            frame: frame,
            edge: edge,
            shown: false,
            reveal: .slide,
            fill: fill
        )
    }

    private func view(_ spec: ShelfHandleSpec) -> ShelfHandleView {
        let view = ShelfHandleView()
        view.frame = CGRect(
            origin: .zero,
            size: ShelfHandle.room(of: spec).size
        )
        return view
    }

    private var running: ShelfHandleSpec.Fill {
        let start = Date(timeIntervalSince1970: 1_000)
        return .init(
            origin: 0.25,
            started: start,
            until: start.addingTimeInterval(10)
        )
    }

    @Test("The handle is a 2 pt core capsule in a 3 pt one, flush")
    func twoTone() {
        #expect(ShelfHandleSpec.inset == 0)
        #expect(ShelfHandleSpec.depth(of: KiwiShelf()) == 3)
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 3)
        let parts = ShelfHandleSpec.parts(of: bounds)
        #expect(parts.outer == bounds)
        // Inset the hairline on every side, the ends included.
        #expect(parts.core == bounds.insetBy(dx: 0.5, dy: 0.5))
        #expect(parts.core.height == 2)
        #expect(ShelfHandleSpec.radius(of: parts.outer) == 1.5)
        #expect(ShelfHandleSpec.radius(of: parts.core) == 1)
        let side = ShelfHandleSpec.parts(
            of: CGRect(x: 0, y: 0, width: 3, height: 400)
        )
        #expect(side.core.width == 2)
    }

    @Test("The hairline is the opposite tone, never the user's colour")
    func hairlineIsNeutral() {
        let light = NSAppearance(named: .aqua)
        let dark = NSAppearance(named: .darkAqua)
        let white = { (hex: String, look: NSAppearance?) -> CGFloat? in
            var ink: NSColor?
            look?.performAsCurrentDrawingAppearance {
                ink = ShelfHandleSpec.hairlineColor(hex: hex)
                    .usingColorSpace(.sRGB)
            }
            return ink?.redComponent
        }
        // Automatic: the label ink is dark on light, light on dark.
        #expect(white("", light) == 1)
        #expect(white("", dark) == 0)
        // A picked colour: by its own lightness, either appearance.
        #expect(white("#FFEE00", dark) == 0)
        #expect(white("#102030", light) == 1)
        var alpha: CGFloat = 0
        light?.performAsCurrentDrawingAppearance {
            alpha = ShelfHandleSpec.hairlineColor(hex: "").alphaComponent
        }
        #expect(alpha == ShelfHandleSpec.hairlineStrength)
    }

    @Test(
        "The core rests and the fill fills at their strengths",
        arguments: ["", "#FF000080"]
    )
    func inkStrengths(hex: String) throws {
        pinRevealLength()
        var spec = spec(running)
        spec.restHex = hex
        let view = view(spec)
        view.appearance = NSAppearance(named: .aqua)
        view.render(spec, animated: true)
        let own: CGFloat = hex.isEmpty ? 1 : 128 / 255
        let rest = try #require(view.core.layer?.backgroundColor?.alpha)
        let fill = try #require(view.fillLayer.backgroundColor?.alpha)
        #expect(abs(rest - own * ShelfHandleSpec.restStrength) < 0.01)
        #expect(abs(fill - own * ShelfHandleSpec.fillStrength) < 0.01)
    }

    @Test("A fill starts at its share of the core, with no length")
    func fillStart() {
        let core = CGRect(x: 0, y: 0, width: 400, height: 2)
        let start = BarMotion.handleFillStart(
            origin: 0.25,
            in: core,
            horizontal: true
        )
        #expect(start == CGRect(x: 100, y: 0, width: 0, height: 2))
        // On a side edge from the top, in the layer's unflipped space.
        let side = CGRect(x: 0, y: 0, width: 2, height: 400)
        let down = BarMotion.handleFillStart(
            origin: 0.25,
            in: side,
            horizontal: false
        )
        #expect(down == CGRect(x: 0, y: 300, width: 2, height: 0))
        #expect(
            BarMotion.handleFillStart(origin: 2, in: core, horizontal: true)
                .minX == 400
        )
    }

    @Test(
        "An approach runs the fill along the core, under Reduce Motion too",
        arguments: [false, true]
    )
    func fillRuns(reduced: Bool) {
        BarMotion.reducedOverride = reduced
        defer { BarMotion.reducedOverride = nil }
        pinRevealLength()
        let spec = spec(running)
        let view = view(spec)
        view.render(self.spec(), animated: false)
        #expect(view.fillLayer.isHidden)
        view.render(spec, animated: true)
        #expect(!view.fillLayer.isHidden)
        #expect(
            view.fillLayer.animation(forKey: BarMotion.handleFillKey) != nil
        )
        #expect(view.fillLayer.superlayer === view.core.layer)
        // Leaving drops it.
        view.render(self.spec(), animated: true)
        #expect(view.fillLayer.isHidden)
        #expect(
            view.fillLayer.animation(forKey: BarMotion.handleFillKey) == nil
        )
    }

    @Test("With no reveal to play the fill steps to full (#3471)")
    func offStepsToFull() {
        let before = BarMotion.revealLength
        BarMotion.revealLength = 0
        defer { BarMotion.revealLength = before }
        let spec = spec(running)
        let view = view(spec)
        view.render(spec, animated: true)
        #expect(!view.fillLayer.isHidden)
        #expect(view.fillLayer.frame == view.core.layer?.bounds)
        #expect(
            view.fillLayer.animation(forKey: BarMotion.handleFillKey) == nil
        )
        // Leaving still drops it.
        view.render(self.spec(), animated: true)
        #expect(view.fillLayer.isHidden)
    }

    @Test("A repeated spec leaves a running fill alone")
    func repeatKeepsTheFill() {
        pinRevealLength()
        let fill = running
        let spec = spec(fill)
        let view = view(spec)
        view.render(spec, animated: true)
        let first = view.fillLayer.animation(forKey: BarMotion.handleFillKey)
        view.render(spec, animated: true)
        #expect(
            view.fillLayer.animation(forKey: BarMotion.handleFillKey)
                === first
        )
    }
}
