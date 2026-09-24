import AppKit
import Testing

@testable import KiwiDeskCore

/// **A steady-state Space Bar render reparents nothing** (#1315).
///
/// Since #1517 the plate is the shelf's and never hosts a view —
/// the glass shows through behind the sections — so the glass run
/// this suite used to watch is gone. What stays owed is the same
/// property one level up: the front-app segment has ONE host per
/// arm (the section root while pinned, else the item container),
/// a render that changes nothing moves nothing, and the shelf
/// places a section's view once. The clauses drive the managers'
/// `sync`, so the arms under test are the production ones.
@Suite("Space Bar front-view churn (#1315)")
@MainActor
struct SpaceBarFrontViewChurnTests {
    /// The machine's Reduce transparency setting is a default this
    /// fixture reasons from, so it is pinned off (#660, #1374).
    init() { LiquidGlassGate.override = { false } }

    /// A plain Space Bar with the front-app segment on. Three
    /// Spaces fit the fixture strip; sixty overflow it with the
    /// segment pinned.
    private static func bar(
        spaces: Int = 3,
        glass: Bool = true
    ) -> SpaceBarManager.Bar {
        var style = SpaceBarLook()
        style.backgroundStyle = .plain
        style.liquidGlass = glass
        style.showFrontApp = true
        let items = (1...spaces).map { n in
            SpaceBarOverlay.Item(
                space: SpaceID(String(n)),
                spaceGlyph: .text(String(n), tinted: true),
                apps: [],
                active: n == 1,
                overflow: 0,
                focusInOverflow: false
            )
        }
        return SpaceBarManager.Bar(
            display: barTitleDisplay,
            items: items,
            frontApp: SpaceBarItemView.App(
                name: "Finder",
                icon: nil,
                glyph: nil,
                focused: true,
                count: 1
            ),
            frontWindow: WindowID(1),
            strip: barTitleStrip,
            style: style,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
    }

    private static func frontViews(
        _ overlay: SpaceBarOverlay
    ) -> [NSView] {
        [
            overlay.frontBox, overlay.frontDivider, overlay.frontIcon,
            overlay.frontGlyph, overlay.frontName,
        ]
    }

    @Test("A second identical render moves no view")
    func steadyRenderMovesNothing() throws {
        let manager = SpaceBarManager()
        manager.sync([Self.bar()])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        let hosts = Self.frontViews(overlay).map(\.superview)
        let order = overlay.itemContainer.subviews
        let frames = Self.frontViews(overlay).map(\.frame)
        let inserts = (
            overlay.itemContainer.insertCount, overlay.root.insertCount
        )
        manager.sync([Self.bar()])
        // A same-host re-add keeps the order; only the parent
        // counts it.
        #expect(
            overlay.itemContainer.insertCount == inserts.0
                && overlay.root.insertCount == inserts.1,
            "a steady render re-added a view"
        )
        for (view, host) in zip(Self.frontViews(overlay), hosts) {
            #expect(view.superview === host, "\(view) changed host")
        }
        // Identity, elementwise: a re-add into the SAME host is a
        // reorder no hook reports.
        #expect(
            overlay.itemContainer.subviews.count == order.count
                && zip(overlay.itemContainer.subviews, order)
                    .allSatisfy { $0 === $1 },
            "a steady render reordered the container"
        )
        #expect(
            Self.frontViews(overlay).map(\.frame) == frames,
            "the segment moved between identical renders"
        )
    }

    /// The host changes with the arm and the segment follows it,
    /// glass or not: the plate never hosts it.
    @Test(
        "The segment follows its host across the arms",
        arguments: [true, false]
    )
    func segmentFollowsTheHost(glass: Bool) throws {
        let manager = SpaceBarManager()
        manager.sync([Self.bar(glass: glass)])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        for view in Self.frontViews(overlay) {
            #expect(
                view.superview === overlay.itemContainer,
                "scrolled-with segment not in the container: \(view)"
            )
        }
        manager.sync([Self.bar(spaces: 60, glass: glass)])
        for view in Self.frontViews(overlay) {
            #expect(
                view.superview === overlay.root,
                "pinned segment not on the section root: \(view)"
            )
        }
        manager.sync([Self.bar(glass: glass)])
        for view in Self.frontViews(overlay) {
            #expect(
                view.superview === overlay.itemContainer,
                "segment did not return to the container: \(view)"
            )
        }
    }

    /// The shelf places a section's view once; a re-layout that
    /// changes nothing reorders nothing on the strip.
    @Test("A shelf re-layout moves no section")
    func shelfPlacesOnce() throws {
        let spaces = SpaceBarManager()
        spaces.sync([Self.bar()])
        let section = try #require(
            spaces.shownOverlay(on: barTitleDisplay)
        )
        let shelves = ShelfManager()
        let shelf = ShelfManager.Shelf(
            display: barTitleDisplay,
            strip: barTitleStrip,
            shelf: KiwiShelf(),
            space: (section, barTitleStrip),
            app: nil
        )
        shelves.sync([shelf])
        let overlay = try #require(
            shelves.overlayForTesting(barTitleDisplay)
        )
        let order = overlay.stripView.subviews
        #expect(section.root.superview === overlay.stripView)
        let inserts = overlay.stripView.insertCount
        shelves.sync([shelf])
        spaces.sync([Self.bar()])
        #expect(
            overlay.stripView.insertCount == inserts,
            "a steady re-layout re-added a section"
        )
        #expect(
            overlay.stripView.subviews.count == order.count
                && zip(overlay.stripView.subviews, order)
                    .allSatisfy { $0 === $1 },
            "a steady re-layout reordered the strip"
        )
    }
}
