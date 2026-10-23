import AppKit
import Testing

@testable import KiwiDeskCore

/// The hidden App Bar mark's window count and the hovered pills
/// (#2567 ▸ Ruling): the count is the App Bar's own, read from its
/// content; a pill never runs past the rim and is never shorter
/// than it is deep; the grown App Bar mark keeps the bar's Fill at
/// both ends of its pill; a side edge stacks the number above the
/// glyph and shows the plural glyph alone past 99; VoiceOver speaks
/// the count at rest.
@Suite("Hidden App Bar mark count (#2567)", .serialized)
@MainActor
struct HiddenMarkCountTests {
    static let mark = CGRect(x: 100, y: 0, width: 36, height: 8)
    static let side = CGRect(x: 0, y: 100, width: 8, height: 36)

    private func spec(
        windows: Int? = nil,
        edge: AppBarEdge = .top,
        rim: CGFloat = 3,
        hovered: Bool = true,
        glass: Bool = false
    ) -> ShelfIndicatorSpec {
        var spec = ShelfIndicatorSpec(
            mark: .line,
            frame: edge.isHorizontal ? Self.mark : Self.side,
            edge: edge,
            fill: "#336699",
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
            spec.count = ShelfIndicatorSpec.count(
                windows,
                font: NSFont.systemFont(ofSize: 12),
                edge: edge,
                pillDepth: spec.pillDepth
            )
        }
        return spec
    }

    @Test("A pill stays inside the rim with 1 pt clear")
    func pillInsideTheRim() {
        #expect(spec(rim: 3).pillDepth == 12)
        #expect(spec(rim: 1).pillDepth == ShelfIndicatorSpec.labelDepth)
        let grown =
            ShelfIndicatorSpec.depth + 2 * ShelfIndicatorSpec.hoverGrowth
        for rim in [1, 2, 3, 4] as [CGFloat] {
            #expect(spec(rim: rim).pillDepth <= grown - 2 * rim - 2)
        }
    }

    @Test("A narrow Space name's pill is round, never an upright oval")
    func spacePillFloor() {
        var narrow = spec(rim: 1)
        narrow.label = ShelfIndicatorSpec.label(
            .text("1", tinted: true),
            font: NSFont.systemFont(ofSize: 12)
        )
        #expect(
            ShelfIndicatorSpec.currentDot + narrow.labelExtra
                >= narrow.pillDepth
        )
    }

    @Test("The grown App Bar mark keeps the Fill at both ends")
    func fillRunEachEnd() throws {
        for windows in [0, 7, 42, 128] {
            let spec = spec(windows: windows)
            let count = try #require(spec.count)
            let grown = BarMotion.hoverPlate(
                mark: spec.frame,
                widen: spec.labelExtra,
                edge: .top,
                hovered: true
            )
            #expect(
                grown.width
                    >= spec.pill(of: count).along
                    + 2 * ShelfIndicatorSpec.fillRun
            )
            #expect(count.showsNumber)
            #expect(count.glyph.height <= spec.pillDepth - 2)
            #expect(count.glyph.height > 0)
        }
    }

    @Test("A side edge stacks the number, and past 99 shows the glyph")
    func sideEdges() throws {
        let two = try #require(spec(windows: 99, edge: .left).count)
        #expect(two.showsNumber)
        #expect(two.glyphName == ShelfIndicatorSpec.countGlyph)
        let many = try #require(spec(windows: 128, edge: .left).count)
        #expect(!many.showsNumber)
        #expect(many.glyphName == ShelfIndicatorSpec.manyGlyph)
        let wide = spec(windows: 99, edge: .left)
        let pill = wide.pill(of: two)
        let grown = BarMotion.hoverPlate(
            mark: wide.frame,
            widen: wide.labelExtra,
            across: wide.countAcross(grown: true),
            edge: .left,
            hovered: true
        )
        #expect(grown.width >= pill.across + 2 * wide.rimWidth + 2)
        // Against the screen side still.
        #expect(grown.minX == wide.frame.minX)
    }

    @Test("VoiceOver reads the count at rest, number last")
    func spokenCount() {
        LocalizationManager.shared.select("en")
        let view = ShelfIndicatorView()
        view.carriesSpaceBar = false
        view.render(spec(windows: 3, hovered: false), animated: false)
        #expect(view.accessibilityLabel() == "App Bar")
        #expect(view.accessibilityValue() as? String == "Hidden, windows: 3")
    }

    @Test("A glass mark draws its plate as a glass box that grows")
    func glassPlate() throws {
        let rest = spec(hovered: false, glass: true)
        let view = ShelfIndicatorView()
        view.frame = CGRect(
            origin: .zero,
            size: ShelfIndicator.room(of: rest).size
        )
        view.render(rest, animated: false)
        guard let box = view.glass else {
            // No Liquid Glass below macOS 26: the solid plate stands.
            #expect(!view.plate.isHidden)
            return
        }
        #expect(view.plate.isHidden)
        let host = try #require(GlassBox.host(of: box.glass))
        let grownSpec = spec(hovered: true, glass: true)
        view.render(grownSpec, animated: false)
        let mark = ShelfIndicator.mark(of: grownSpec, in: view.bounds)
        #expect(
            host.frame
                == BarMotion.hoverPlate(mark: mark, edge: .top, hovered: true)
        )
        view.render(spec(hovered: true, glass: false), animated: false)
        #expect(view.glass == nil)
        #expect(!view.plate.isHidden)
    }
}
