import CoreGraphics
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Bars preview draws the live shelf's placement (#1517,
/// gui.md ▸ a preview claiming engine behaviour asks the engine):
/// its arithmetic, not its pixels, is what a regression moves —
/// runs cut at their slots, one plate under both, and the Space
/// section held at Core's hard floor.
///
/// `@MainActor` because the preview is a `View`; it spends only
/// arithmetic there — nothing is rendered.
@Suite("Shelf strip preview")
@MainActor
struct ShelfStripPreviewTests {
    private static func spec(
        items: Int,
        length: CGFloat
    ) -> HomeCardBarsTile.BarSpec {
        HomeCardBarsTile.BarSpec(
            fill: "#333333",
            highlight: "#88BB44",
            items: (0..<items).map { _ in
                HomeCardBarsTile.BarItem(color: "#FFFFFF", length: length)
            },
            alignment: .start,
            spans: false,
            boxed: false,
            thickness: 25,
            corner: 6,
            itemCorner: 4,
            gap: 5,
            indicator: .edgeMark,
            outlineWidth: 1.8,
            edgeMarkWidth: 2.7,
            borderWidth: 0,
            borderColor: "#FFFFFF",
            fontSize: 12,
            shelf: KiwiShelf(),
            sheen: 0
        )
    }

    private static func preview(
        spaces: Int,
        windows: Int,
        shelf: KiwiShelf = KiwiShelf()
    ) -> ShelfStripPreview {
        ShelfStripPreview(
            shelf: shelf,
            space: spaces > 0 ? spec(items: spaces, length: 22) : nil,
            app: windows > 0 ? spec(items: windows, length: 60) : nil,
            edge: .top,
            vertical: false,
            scale: 1.8
        )
    }

    @Test("An overflowing shelf cuts each run at its slot")
    func runsStayInTheirSlots() throws {
        let preview = Self.preview(spaces: 20, windows: 12)
        let placed = preview.arrangement(length: 480)
        let space = try #require(placed.space)
        let app = try #require(placed.app)
        #expect(placed.divider != nil, "the fixture must be full")
        let spaceRun = preview.run(try #require(preview.space), in: space)
        let appRun = preview.run(try #require(preview.app), in: app)
        #expect(spaceRun.lowerBound >= space.offset)
        #expect(spaceRun.upperBound <= space.offset + space.length + 0.01)
        #expect(appRun.lowerBound >= app.offset)
        #expect(appRun.upperBound <= app.offset + app.length + 0.01)
        #expect(spaceRun.upperBound <= appRun.lowerBound)
        #expect(preview.overflows(try #require(preview.space), space))
    }

    @Test("One plate spans both runs, and the strip under Full")
    func onePlate() throws {
        let preview = Self.preview(spaces: 3, windows: 2)
        let placed = preview.arrangement(length: 480)
        let span = try #require(preview.plateSpan(placed, length: 480))
        let spaceRun = preview.run(
            try #require(preview.space),
            in: try #require(placed.space)
        )
        let appRun = preview.run(
            try #require(preview.app),
            in: try #require(placed.app)
        )
        #expect(span.lowerBound == min(spaceRun.lowerBound, appRun.lowerBound))
        #expect(span.upperBound == max(spaceRun.upperBound, appRun.upperBound))
        var full = KiwiShelf()
        full.backgroundFit = .full
        let spanning = Self.preview(spaces: 3, windows: 2, shelf: full)
        #expect(
            spanning.plateSpan(
                spanning.arrangement(length: 480),
                length: 480
            ) == 0...480
        )
        var boxed = KiwiShelf()
        boxed.backgroundStyle = .boxed
        let boxes = Self.preview(spaces: 3, windows: 2, shelf: boxed)
        #expect(
            boxes.plateSpan(boxes.arrangement(length: 480), length: 480)
                == nil
        )
    }

    /// The Space section never shrinks below the engine's hard
    /// floor for the active Space — the preview hands it one.
    @Test("The Space section keeps Core's hard floor")
    func spaceKeepsItsFloor() throws {
        var shelf = KiwiShelf()
        shelf.minimum = KiwiShelf.minimumRange.lowerBound
        let preview = Self.preview(spaces: 30, windows: 40, shelf: shelf)
        let placed = preview.arrangement(length: 300)
        let space = try #require(placed.space)
        // Core's floor is in points; the preview draws it at its
        // own scale.
        let unit = preview.unit
        #expect(unit == 25 / shelf.thickness)
        let floor =
            ShelfArrangement.hardFloor(
                activeExtent: 22 / unit,
                thickness: shelf.thickness,
                gap: 5 / unit
            ) * unit
        #expect(space.length >= floor - 0.01)
    }

    /// A labelled pip draws its rounded ends' clearance (#1763),
    /// so the need the arrangement is handed carries it too.
    @Test("A run's need carries the clearance its pips draw")
    func needCarriesPipClearance() {
        let preview = Self.preview(spaces: 3, windows: 0)
        var bare = Self.spec(items: 3, length: 22)
        bare.boxed = true
        bare.itemCorner = 7
        var labelled = bare
        labelled.items = labelled.items.map {
            var item = $0
            item.label = "1"
            return item
        }
        let inset = labelled.pipEndInset(scale: preview.scale)
        #expect(inset > 0)
        #expect(
            abs(preview.need(labelled) - preview.need(bare) - 6 * inset)
                < 1e-9
        )
        // No box, no rounded end to clear.
        labelled.boxed = false
        bare.boxed = false
        #expect(labelled.pipEndInset(scale: preview.scale) == 0)
        #expect(preview.need(labelled) == preview.need(bare))
    }

    /// The need above is only half: the pip must DRAW the inset it
    /// measures, through the same member, exactly once (#1763).
    @Test("A labelled pip draws the clearance its need counts")
    func pipDrawsItsClearance() throws {
        let url = SourceScan.repoRoot(from: "\(#filePath)")
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/HomeCardPlate+BarStrip.swift"
            )
        let source = try SourceScan.strippedSource(at: url)
        #expect(!source.isEmpty)
        let draws =
            source.components(
                separatedBy: "spec.pipEndInset(scale: scale)"
            ).count - 1
        #expect(draws == 1)
    }
}
