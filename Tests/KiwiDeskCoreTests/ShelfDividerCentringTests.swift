import AppKit
import Testing

@testable import KiwiDeskCore

/// The section divider sits in the middle of the gap the user SEES
/// (#1779): between the last thing the one section draws and the
/// first the other draws — the glyphs on a plate, the item boxes
/// on a boxed shelf — in either order. Each bar insets its run and
/// its items' content by its own amounts, so a divider centred on
/// the slot gutter reads off-centre; measured here on the real
/// bars through the real `ShelfManager` wiring.
@Suite("Shelf divider centring", .serialized)
@MainActor
struct ShelfDividerCentringTests {
    private static let strip = CGRect(x: 0, y: 0, width: 1000, height: 28)
    private static let display = DisplayID(17)

    init() { LiquidGlassGate.override = { false } }

    private static func image() -> NSImage {
        NSImage(size: NSSize(width: 64, height: 64), flipped: false) {
            NSColor.black.setFill()
            $0.fill()
            return true
        }
    }

    private static func spaceItems() -> [SpaceBarOverlay.Item] {
        (1...3).map { n in
            SpaceBarOverlay.Item(
                space: SpaceID(String(n)),
                spaceGlyph: .symbol("star"),
                apps: [
                    SpaceBarItemView.App(
                        name: "App\(n)",
                        icon: image(),
                        glyph: nil,
                        focused: false,
                        count: 1,
                        windows: [WindowID(UInt32(n))]
                    )
                ],
                active: n == 1,
                after: .none
            )
        }
    }

    private static func appItems() -> [AppBarOverlay.Item] {
        (1...3).map { n in
            AppBarOverlay.Item(
                id: WindowID(UInt32(10 + n)),
                text: "App \(n)",
                icon: image(),
                count: 1
            )
        }
    }

    /// The shelf both bars share, pinned where a default would
    /// otherwise decide the geometry (tests.md #660).
    private static func shelf(
        order: KiwiShelf.Order,
        style: AppBarStyle.BackgroundStyle
    ) -> KiwiShelf {
        var shelf = KiwiShelf()
        shelf.order = order
        shelf.backgroundStyle = style
        shelf.liquidGlass = false
        shelf.itemGap = 6
        return shelf
    }

    /// The two sections drawn onto one shelf as `updateBars`
    /// places them, and that shelf's overlay.
    private func drawn(
        _ shelf: KiwiShelf
    ) throws -> (SpaceBarOverlay, AppBarOverlay, ShelfOverlay) {
        let depth = Self.strip.height
        var spaceLook = SpaceBarLook(
            shelf: shelf,
            bar: SpaceBarStyle(),
            sheen: 0
        )
        spaceLook.edge = .top
        var appLook = AppBarLook()
        appLook.shelf = shelf
        appLook.edge = .top
        appLook.content = .icon
        let placed = ShelfArrangement.arrange(
            length: Self.strip.width,
            spaceNeed: SpaceBarOverlay.naturalLength(
                items: Self.spaceItems(),
                depth: depth,
                look: spaceLook
            ),
            appNeed: AppBarOverlay.naturalLength(
                items: Self.appItems(),
                style: appLook,
                thickness: depth,
                capAxis: Self.strip.width
            ),
            spaceFloor: 0,
            shelf: shelf
        )
        let spaceSlot = try #require(placed.space)
        let appSlot = try #require(placed.app)
        spaceLook.alignment = spaceSlot.alignment
        appLook.alignment = appSlot.alignment
        let space = SpaceBarOverlay()
        space.show(
            items: Self.spaceItems(),
            strip: spaceSlot.rect(in: Self.strip, horizontal: true),
            style: spaceLook,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
        let app = AppBarOverlay()
        app.show(
            items: Self.appItems(),
            activeIndex: 0,
            strip: appSlot.rect(in: Self.strip, horizontal: true),
            style: appLook,
            capAxis: Self.strip.width
        )
        let shelves = ShelfManager()
        shelves.sync([
            .init(
                display: Self.display,
                edge: .top,
                strip: Self.strip,
                shelf: shelf,
                sheen: 0,
                space: space,
                app: app
            )
        ])
        let overlay = try #require(
            shelves.overlayForTesting(Self.display, edge: .top)
        )
        space.root.layoutSubtreeIfNeeded()
        app.root.layoutSubtreeIfNeeded()
        return (space, app, overlay)
    }

    /// `view`'s along-axis span in the shelf strip's coordinates.
    private func span(
        _ view: NSView,
        in overlay: ShelfOverlay
    ) -> ClosedRange<CGFloat> {
        let rect = overlay.stripView.convert(view.bounds, from: view)
        return rect.minX...rect.maxX
    }

    @Test(
        "The divider halves the drawn gap, either order, plate or boxed",
        arguments: [KiwiShelf.Order.spacesFirst, .appsFirst],
        [AppBarStyle.BackgroundStyle.plain, .boxed]
    )
    func dividerHalvesTheDrawnGap(
        order: KiwiShelf.Order,
        style: AppBarStyle.BackgroundStyle
    ) throws {
        let (space, app, overlay) = try drawn(
            Self.shelf(order: order, style: style)
        )
        #expect(!overlay.divider.isHidden)
        let spacesFirst = order == .spacesFirst
        let spaceItem = try #require(
            spacesFirst ? space.itemViews.last : space.itemViews.first
        )
        let appItem = try #require(
            spacesFirst ? app.itemViews.first : app.itemViews.last
        )
        let boxed = style == .boxed
        let spaceInk: NSView =
            boxed
            ? spaceItem
            : try #require(
                spacesFirst
                    ? spaceItem.appViews.last : spaceItem.identifierImage
            )
        let appInk: NSView = boxed ? appItem : appItem.iconView
        let spaceSpan = span(spaceInk, in: overlay)
        let appSpan = span(appInk, in: overlay)
        let line = overlay.divider.frame.midX
        let before =
            spacesFirst
            ? line - spaceSpan.upperBound : line - appSpan.upperBound
        let after =
            spacesFirst
            ? appSpan.lowerBound - line : spaceSpan.lowerBound - line
        #expect(before > 0 && after > 0)
        #expect(
            abs(before - after) <= 0.5,
            Comment(rawValue: "before \(before), after \(after)")
        )
        overlay.hide()
    }

    /// A section whose run overflows its slot draws to the slot's
    /// edge, so the gutter is the gap; a section that reports no
    /// content keeps the slot too.
    @Test("An overflowing or silent section falls back to its slot")
    func slotFallback() {
        let slots = [
            CGRect(x: 100, y: 0, width: 300, height: 28),
            CGRect(x: 406, y: 0, width: 200, height: 28),
        ]
        let frame = ShelfOverlay.dividerFrame(
            slots: slots,
            contents: [
                CGRect(x: -40, y: 0, width: 400, height: 28),
                .zero,
            ],
            strip: Self.strip,
            horizontal: true
        )
        #expect(frame?.midX == 403)
    }
}
