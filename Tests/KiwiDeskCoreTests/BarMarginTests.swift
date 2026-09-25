import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// One placement rule for the shelf (#1516, #1517): from the
/// screen edge inwards, the shelf's OUTER margin (absolute; 0 is
/// flush), the strip, the shelf's INNER margin, then the
/// windows' own outer gap — which alone keeps the focus ring's
/// room, so the inner margin is extra and needs no floor. Both
/// bars share the one strip, so the reservation is taken once
/// whichever bars show.
@Suite("Bar margins")
struct BarMarginTests {
    // Pinned (#531): every number below reasons from it.
    private let visible = CGRect(
        x: 0,
        y: 25,
        width: 1920,
        height: 1055
    )

    private func shelf(
        edge: AppBarEdge,
        outer: CGFloat = 0,
        inner: CGFloat = 0
    ) -> KiwiShelf {
        var shelf = KiwiShelf()
        shelf.edge = edge
        // Pinned (#660): the sums below reason from it.
        shelf.thickness = 32
        shelf.outerMargin = outer
        shelf.innerMargin = inner
        return shelf
    }

    /// Settings carrying `shelf`, with only the scrolling App Bar
    /// on unless `spaceBar` is.
    private func settings(
        _ shelf: KiwiShelf,
        spaceBar: Bool = false
    ) -> TilingSettings {
        var settings = TilingSettings()
        settings.kiwishelf = shelf
        settings.spaceBarStyle.enabled = spaceBar
        settings.monocle.appBar.enabled = false
        settings.scrolling.appBar.enabled = true
        return settings
    }

    @Test("The shelf strip sits its outer margin in from the edge")
    func outerMarginInsetsTheStrip() {
        let shelf = shelf(edge: .top, outer: 8)
        let strip = ShelfGeometry.strip(in: visible, shelf: shelf)
        #expect(strip.minY == visible.minY + 8)
        #expect(strip.height == 32)
        #expect(strip.width == visible.width)
        let remaining = ShelfGeometry.remainingFrame(
            in: visible,
            shelf: shelf
        )
        #expect(remaining.minY == visible.minY + 8 + 32)
    }

    @Test("The inner margin reserves room, moving no strip")
    func innerMarginIsAdditive() {
        let shelf = shelf(edge: .bottom, inner: 6)
        let strip = ShelfGeometry.strip(in: visible, shelf: shelf)
        #expect(strip.maxY == visible.maxY)
        let remaining = ShelfGeometry.remainingFrame(
            in: visible,
            shelf: shelf
        )
        #expect(remaining.maxY == visible.maxY - 32 - 6)
        #expect(shelf.reservation == 38)
    }

    /// The windows keep their outer gap beyond the shelf — never
    /// the inner gap — and at the default margins it is flush.
    @Test("The shelf is flush by default; windows keep the outer gap")
    func flushAndWindowsKeepTheOuterGap() {
        let settings = settings(shelf(edge: .bottom))
        let outer = Gaps.Outer(top: 10, bottom: 10, left: 10, right: 10)
        let area = LayoutContext.usable(
            settings.layoutBounds(from: visible, mode: .scrolling),
            outer: outer
        )
        #expect(area.maxY == visible.maxY - 32 - 10)
    }

    @Test("Shelf margins move the strip in and the windows further")
    func marginsApply() {
        let shelf = shelf(edge: .bottom, outer: 5, inner: 7)
        let strip = ShelfGeometry.strip(in: visible, shelf: shelf)
        #expect(strip.maxY == visible.maxY - 5)
        #expect(strip.height == 32)
        let area = LayoutContext.usable(
            settings(shelf).layoutBounds(from: visible, mode: .scrolling),
            outer: Gaps.uniform(10).outer
        )
        #expect(area.maxY == visible.maxY - 5 - 32 - 7 - 10)
    }

    /// Both bars sit on the one strip (#1517): showing the Space
    /// Bar beside the App Bar reserves nothing more.
    @Test("Both bars share one reservation")
    func bothBarsReserveOnce() {
        let shelf = shelf(edge: .top, outer: 2, inner: 3)
        let one = settings(shelf).layoutBounds(from: visible, mode: .scrolling)
        let both = settings(shelf, spaceBar: true)
            .layoutBounds(from: visible, mode: .scrolling)
        #expect(both == one)
        #expect(both.minY == visible.minY + 2 + 32 + 3)
    }

    @Test("Absent keys decode to 0 and a negative one is floored")
    func decodingDefaultsAndFloors() throws {
        let decoder = JSONDecoder()
        let bare = try decoder.decode(
            KiwiShelf.self,
            from: Data("{}".utf8)
        )
        #expect(bare.outerMargin == 0)
        #expect(bare.innerMargin == 0)
        let negative = try decoder.decode(
            KiwiShelf.self,
            from: Data(
                #"{"outer_margin": -3, "inner_margin": -1}"#.utf8
            )
        )
        #expect(negative.outerMargin == 0)
        #expect(negative.innerMargin == 0)
    }
}

/// The verbs, through the real dispatch: the global setters on
/// both bars and a layout's override.
@Suite("Bar margin commands")
@MainActor
struct BarMarginCommandTests {
    private func makeCore() -> KiwiCore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        return makeTestCore(configDirectory: directory)
    }

    @Test("app_bar and space_bar set_*_margin write the leaves")
    func globalSetters() {
        let core = makeCore()
        #expect(
            core.execute(
                "kiwishelf.set_outer_margin",
                args: [.number(12)]
            ).isSuccess
        )
        #expect(
            core.execute(
                "kiwishelf.set_inner_margin",
                args: [.number(4)]
            ).isSuccess
        )
        #expect(core.tiler.settings.kiwishelf.outerMargin == 12)
        #expect(core.tiler.settings.kiwishelf.innerMargin == 4)
        #expect(
            core.execute(
                "kiwishelf.set_outer_margin",
                args: [.number(6)]
            ).isSuccess
        )
        #expect(
            core.execute(
                "kiwishelf.set_inner_margin",
                args: [.number(-2)]
            ).isSuccess
        )
        #expect(core.tiler.settings.kiwishelf.outerMargin == 6)
        #expect(core.tiler.settings.kiwishelf.innerMargin == 0)
        #expect(
            !core.execute(
                "kiwishelf.set_outer_margin",
                args: [.string("x")]
            ).isSuccess
        )
    }

    @Test("The margins have no per-layout override (#1517)")
    func layoutOverridesRetired() {
        let core = makeCore()
        #expect(
            !core.execute(
                "scroll.set_app_bar_outer_margin",
                args: [.number(9)]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "monocle.set_app_bar_inner_margin",
                args: [.number(3)]
            ).isSuccess
        )
        #expect(core.tiler.settings.kiwishelf.outerMargin == 0)
    }
}
