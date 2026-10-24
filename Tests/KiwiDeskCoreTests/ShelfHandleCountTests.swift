import AppKit
import Testing

@testable import KiwiDeskCore

/// The App Bar handle's window count and the hovered pills
/// (#2567 ▸ Ruling): the count is the App Bar's own, read from its
/// content; a pill never runs past the rim and is never shorter
/// than it is deep; the grown App Bar handle keeps the bar's Fill at
/// both ends of its pill; a side edge stacks the number above the
/// glyph and shows the plural glyph alone past 99; VoiceOver speaks
/// the count at rest.
@Suite("App Bar handle count (#2567)", .serialized)
@MainActor
struct ShelfHandleCountTests {
    init() { LiquidGlassGate.override = { false } }

    static let mark = CGRect(x: 100, y: 0, width: 36, height: 8)
    static let side = CGRect(x: 0, y: 100, width: 8, height: 36)

    private func spec(
        windows: Int? = nil,
        edge: AppBarEdge = .top,
        rim: CGFloat = 3,
        hovered: Bool = true,
        glass: Bool = false
    ) -> ShelfHandleSpec {
        var spec = ShelfHandleSpec(
            mark: .line,
            frame: edge.isHorizontal ? Self.mark : Self.side,
            edge: edge,
            fill: GlassFill(hex: "#336699"),
            currentInk: "#000000",
            ink: "#AAAAAA",
            emptyInk: "#555555",
            highlight: "#FF0000",
            shown: false,
            hovered: hovered,
            reveal: .slide,
            rimWidth: rim,
            glass: glass
        )
        if let windows {
            spec.count = ShelfHandleSpec.count(
                windows,
                font: NSFont.systemFont(ofSize: 12),
                edge: edge,
                pillDepth: spec.pillDepth
            )
        }
        return spec
    }

    @Test("Top and bottom always show the number; the glyph fits")
    func topShowsTheNumber() throws {
        for windows in [7, 42, 128] {
            let spec = spec(windows: windows)
            let count = try #require(spec.count)
            #expect(count.showsNumber)
            // A top edge's plate grows along it, never deeper.
            #expect(spec.growth.across == 0)
            #expect(count.glyph.height > 0)
            #expect(count.glyph.height <= spec.pillDepth - 2)
        }
    }

    @Test("A side edge stacks the number, and past 99 shows the glyph")
    func sideEdges() throws {
        let two = try #require(spec(windows: 99, edge: .left).count)
        #expect(two.showsNumber)
        #expect(two.glyphName == ShelfHandleSpec.countGlyph)
        let many = try #require(spec(windows: 128, edge: .left).count)
        #expect(!many.showsNumber)
        #expect(many.glyphName == ShelfHandleSpec.manyGlyph)
        let wide = spec(windows: 99, edge: .left)
        let grown = BarMotion.hoverPlate(
            mark: wide.frame,
            growth: wide.growth,
            edge: .left,
            hovered: true
        )
        // Wider than the plain growth, against the screen side still.
        #expect(
            grown.width
                > ShelfHandleSpec.depth + 2 * ShelfHandleSpec.hoverGrowth
        )
        #expect(grown.minX == wide.frame.minX)
    }

    @Test("VoiceOver reads the count at rest, number last")
    func spokenCount() {
        LocalizationManager.shared.select("en")
        let view = ShelfHandleView()
        view.carriesSpaceBar = false
        view.render(spec(windows: 3, hovered: false), animated: false)
        #expect(view.accessibilityLabel() == "App Bar")
        #expect(view.accessibilityValue() as? String == "Hidden, windows: 3")
    }

    @Test("A glass mark draws its plate as a glass box that grows")
    func glassPlate() throws {
        let rest = spec(windows: 42, hovered: false, glass: true)
        let view = ShelfHandleView()
        view.frame = CGRect(
            origin: .zero,
            size: ShelfHandle.room(of: rest).size
        )
        view.render(rest, animated: false)
        guard #available(macOS 26, *) else {
            // No Liquid Glass below macOS 26: the solid plate stands.
            #expect(view.glass == nil)
            #expect(!view.plate.isHidden)
            return
        }
        let box = try #require(view.glass)
        #expect(view.plate.isHidden)
        // The tint only `GlassBox.place` lays under the glass.
        #expect(box.tint.superview != nil)
        let host = try #require(GlassBox.host(of: box.glass))
        let grownSpec = spec(windows: 42, hovered: true, glass: true)
        let mark = ShelfHandle.mark(of: grownSpec, in: view.bounds)
        let grown = BarMotion.hoverPlate(
            mark: mark,
            growth: grownSpec.growth,
            edge: .top,
            hovered: true
        )
        // One capsule radius at both sizes: the grown plate's.
        let capsule = min(grown.width, grown.height) / 2
        let glass = try #require(box.glass as? NSGlassEffectView)
        #expect(glass.cornerRadius == capsule)
        view.render(grownSpec, animated: false)
        #expect(host.frame == grown)
        #expect(glass.cornerRadius == capsule)
        view.render(
            spec(windows: 42, hovered: true, glass: false),
            animated: false
        )
        #expect(view.glass == nil)
        #expect(!view.plate.isHidden)
        // Dropped, not merely forgotten: the box leaves the view.
        #expect(host.superview == nil)
        #expect(box.tint.superview == nil)
    }
}
