import AppKit
import Testing

@testable import KiwiDeskCore

/// An overflowing run keeps the end pads a fitting one has, where
/// its alignment puts them (#1830): at a strip exactly the bar's
/// natural length and one point shorter — fitting, then
/// overflowing — the run's leading item and its trailing end sit
/// where they sat, so crossing into overflow starts the scroll
/// and moves no end, and a divider drag moves no outer margin.
@Suite("Shelf overflow keeps its end pads", .serialized)
@MainActor
struct ShelfOverflowPadTests {
    init() { LiquidGlassGate.override = { false } }

    private static let depth: CGFloat = 28
    private static let capAxis: CGFloat = 2000

    private static func shelf(_ alignment: KiwiShelf.Alignment)
        -> KiwiShelf
    {
        var shelf = KiwiShelf()
        shelf.liquidGlass = false
        shelf.itemGap = 6
        shelf.alignment = alignment
        return shelf
    }

    private static func strip(_ length: CGFloat) -> CGRect {
        CGRect(x: 0, y: 0, width: length, height: depth)
    }

    /// `view`'s span along the axis in `root`'s coordinates.
    private static func span(_ view: NSView, in root: NSView)
        -> ClosedRange<CGFloat>
    {
        let frame = view.convert(view.bounds, to: root)
        return frame.minX...frame.maxX
    }

    // MARK: - App Bar

    private static func appItems() -> [AppBarOverlay.Item] {
        (1...4).map {
            AppBarOverlay.Item(
                id: WindowID(UInt32($0)),
                text: "Window \($0)",
                icon: nil
            )
        }
    }

    /// The first item's span and the run's clear end: the last
    /// item's end while it fits, the viewport's end once it scrolls.
    private func appRun(
        _ alignment: KiwiShelf.Alignment,
        length: CGFloat
    ) throws -> (first: ClosedRange<CGFloat>, end: CGFloat) {
        var look = AppBarLook()
        look.shelf = Self.shelf(alignment)
        look.alignment = alignment
        let overlay = AppBarOverlay()
        overlay.show(
            items: Self.appItems(),
            activeIndex: 0,
            strip: Self.strip(length),
            style: look,
            capAxis: Self.capAxis
        )
        let first = try #require(overlay.itemViews.first)
        let last = try #require(overlay.itemViews.last)
        let lastEnd = Self.span(last, in: overlay.root).upperBound
        let viewEnd = overlay.itemContainer.frame.maxX
        return (Self.span(first, in: overlay.root), min(lastEnd, viewEnd))
    }

    @Test(
        "The App Bar's ends hold across the overflow threshold",
        arguments: [KiwiShelf.Alignment.start, .center, .end]
    )
    func appBarEndsHold(alignment: KiwiShelf.Alignment) throws {
        var look = AppBarLook()
        look.shelf = Self.shelf(alignment)
        let natural = AppBarOverlay.naturalLength(
            items: Self.appItems(),
            style: look,
            thickness: Self.depth,
            capAxis: Self.capAxis
        )
        let fits = try appRun(alignment, length: natural)
        let scrolls = try appRun(alignment, length: natural - 1)
        let tolerance = ShelfOverflow.clipTolerance
        #expect(
            abs(fits.first.lowerBound - scrolls.first.lowerBound)
                <= tolerance
        )
        #expect(abs(fits.end - scrolls.end) <= tolerance)
    }

    // MARK: - Space Bar

    private static func spaceItems() -> [SpaceBarOverlay.Item] {
        (1...4).map { n in
            SpaceBarOverlay.Item(
                space: SpaceID(String(n)),
                spaceGlyph: .symbol("star"),
                apps: [],
                active: n == 1,
                after: .none
            )
        }
    }

    private func spaceLook(_ alignment: KiwiShelf.Alignment)
        -> SpaceBarLook
    {
        var look = SpaceBarLook(
            shelf: Self.shelf(alignment),
            bar: SpaceBarStyle(),
            sheen: 0
        )
        look.alignment = alignment
        return look
    }

    private func spaceRun(
        _ alignment: KiwiShelf.Alignment,
        length: CGFloat
    ) throws -> (first: ClosedRange<CGFloat>, end: CGFloat) {
        let overlay = SpaceBarOverlay()
        overlay.show(
            items: Self.spaceItems(),
            strip: Self.strip(length),
            style: spaceLook(alignment),
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
        let first = try #require(overlay.itemViews.first)
        let last = try #require(overlay.itemViews.last)
        let lastEnd = Self.span(last, in: overlay.root).upperBound
        let viewEnd = overlay.itemContainer.frame.maxX
        return (Self.span(first, in: overlay.root), min(lastEnd, viewEnd))
    }

    @Test(
        "The Space Bar's ends hold across the overflow threshold",
        arguments: [KiwiShelf.Alignment.start, .center, .end]
    )
    func spaceBarEndsHold(alignment: KiwiShelf.Alignment) throws {
        let natural = SpaceBarOverlay.naturalLength(
            items: Self.spaceItems(),
            depth: Self.depth,
            look: spaceLook(alignment)
        )
        let fits = try spaceRun(alignment, length: natural)
        let scrolls = try spaceRun(alignment, length: natural - 1)
        let tolerance = ShelfOverflow.clipTolerance
        #expect(
            abs(fits.first.lowerBound - scrolls.first.lowerBound)
                <= tolerance
        )
        #expect(abs(fits.end - scrolls.end) <= tolerance)
    }

    /// The floor budgets the pads an overflowing Space run keeps.
    @Test("The hard floor carries the Space Bar's end pads")
    func floorCarriesPads() {
        let pads = SpaceBarOverlay.endPads(gap: 6)
        #expect(
            ShelfArrangement.hardFloor(
                activeExtent: 50,
                thickness: Self.depth,
                gap: 6,
                endPads: pads
            )
                == 50
                + ShelfArrangement.fadeRoom(thickness: Self.depth, gap: 6)
                + pads
        )
    }
}
