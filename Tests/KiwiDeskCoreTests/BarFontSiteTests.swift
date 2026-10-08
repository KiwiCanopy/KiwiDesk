import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// Every bar text site draws the shelf's family (#1681), built
/// through the real views; the App Font never follows it.
@Suite("Bar text sites take the shelf's font")
@MainActor
struct BarFontSiteTests {
    private static let family = "Menlo"

    init() { LiquidGlassGate.override = { false } }

    private static var shelf: KiwiShelf {
        var shelf = KiwiShelf()
        shelf.fontFamily = family
        return shelf
    }

    private func spaceItem(
        glyph: String? = nil,
        overflow: Int = 0
    ) -> SpaceBarItemView {
        let view = SpaceBarItemView(
            frame: CGRect(x: 0, y: 0, width: 140, height: 40)
        )
        let app = SpaceBarItemView.App(
            name: "Safari",
            icon: nil,
            glyph: glyph,
            focused: true,
            count: 3
        )
        view.configure(
            identity: .space(SpaceID("1")),
            spaceGlyph: .text("1", tinted: true),
            apps: [app],
            active: true,
            horizontal: true,
            style: SpaceBarLook(
                shelf: Self.shelf,
                bar: SpaceBarStyle(),
                sheen: 0
            ),
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            ),
            after: .init(
                windows: (0..<overflow).map { WindowID(UInt32(900 + $0)) }
            )
        )
        view.layout()
        return view
    }

    private func appItem(count: Int = 1) -> AppBarItemView {
        let view = AppBarItemView(
            frame: NSRect(x: 0, y: 0, width: 160, height: 40)
        )
        view.configure(
            id: WindowID(1),
            text: "Zed",
            icon: nil,
            glyph: nil,
            count: count,
            active: true,
            horizontal: true,
            style: AppBarLook(
                shelf: Self.shelf,
                bar: AppBarStyle(),
                sheen: 0
            )
        )
        view.layout()
        return view
    }

    @Test("The Space identifier draws the family")
    func spaceIdentifier() throws {
        try #require(BarFont.isInstalled(Self.family))
        let font = try #require(spaceItem().identifierLabel.font)
        #expect(font.familyName == Self.family)
    }

    @Test("The Space Bar's overflow count draws the family")
    func spaceOverflowBadge() throws {
        try #require(BarFont.isInstalled(Self.family))
        let view = spaceItem(overflow: 3)
        let font = try #require(view.overflowBadge.font)
        #expect(font.familyName == Self.family)
    }

    /// The App Font is the glyph, never bar text.
    @Test("An App Font glyph keeps the App Font")
    func appFontStays() throws {
        let view = spaceItem(glyph: ":safari:")
        let field = try #require(view.appViews.first as? NSTextField)
        try #require(AppFont.font(size: 12) != nil, "no App Font")
        #expect(field.font?.fontName == AppFont.fontName)
    }

    @Test("The App Bar's title draws the family")
    func appTitle() throws {
        try #require(BarFont.isInstalled(Self.family))
        let font = try #require(appItem().label.font)
        #expect(font.familyName == Self.family)
    }

    @Test("The App Bar's group count draws the family")
    func appBadge() throws {
        try #require(BarFont.isInstalled(Self.family))
        let font = try #require(appItem(count: 3).badge.font)
        #expect(font.familyName == Self.family)
    }

    /// The slot width is measured in the face the item draws, or a
    /// wider face truncates the item that set the width.
    @Test("The App Bar measures its slots in the family")
    func appSlotMeasure() throws {
        try #require(BarFont.isInstalled(Self.family))
        let items = [
            AppBarOverlay.Item(
                id: WindowID(1),
                text: "Wide Window Title",
                icon: nil,
                glyph: nil,
                count: 1
            )
        ]
        func width(_ shelf: KiwiShelf) -> CGFloat {
            AppBarOverlay.autoSlotWidth(
                items: items,
                style: AppBarLook(
                    shelf: shelf,
                    bar: AppBarStyle(),
                    sheen: 0
                ),
                horizontal: true,
                thickness: 40
            )
        }
        #expect(width(Self.shelf) != width(KiwiShelf()))
    }

    @Test("A Space's app count badge draws the family")
    func spaceAppBadge() throws {
        try #require(BarFont.isInstalled(Self.family))
        let view = spaceItem()
        let badge = try #require(view.badgeViews.first)
        #expect(badge.font?.familyName == Self.family)
    }

    /// The front-app segment's name, drawn and measured: a measure
    /// in another face than the draw slides the run off its
    /// alignment.
    @Test("The front-app name draws and measures in the family")
    func frontAppName() throws {
        try #require(BarFont.isInstalled(Self.family))
        func bar(_ shelf: KiwiShelf) -> SpaceBarManager.Bar {
            var style = SpaceBarLook(
                shelf: shelf,
                bar: SpaceBarStyle(),
                sheen: 0
            )
            style.showFrontApp = true
            return SpaceBarManager.Bar(
                display: barTitleDisplay,
                items: [
                    SpaceBarOverlay.Item(
                        space: SpaceID("1"),
                        spaceGlyph: .text("1", tinted: true),
                        apps: [],
                        active: true,
                        after: .none
                    )
                ],
                frontApp: Self.frontApp,
                frontWindow: WindowID(1),
                strip: barTitleStrip,
                style: style,
                stateMarkColors: StateMarkColors(
                    sticky: "#ffffff",
                    floating: "#ffffff"
                )
            )
        }
        let manager = SpaceBarManager()
        manager.sync([bar(Self.shelf)])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        #expect(overlay.frontName.font?.familyName == Self.family)
        func extent(_ shelf: KiwiShelf) -> CGFloat {
            var style = SpaceBarLook(
                shelf: shelf,
                bar: SpaceBarStyle(),
                sheen: 0
            )
            style.showFrontApp = true
            return overlay.frontExtent(
                Self.frontApp,
                depth: barTitleStrip.height,
                horizontal: true,
                style: style
            )
        }
        #expect(extent(Self.shelf) != extent(KiwiShelf()))
    }

    private static let frontApp = SpaceBarItemView.App(
        name: "Wide Window Title",
        icon: nil,
        glyph: nil,
        focused: true,
        count: 1
    )

    @Test("A shelf count draws the family")
    func shelfCount() throws {
        try #require(BarFont.isInstalled(Self.family))
        let view = ShelfCountView(side: .after)
        view.configure(
            count: 12,
            horizontal: true,
            fontSize: 14,
            shelf: Self.shelf,
            ink: .white,
            hoverInk: .red
        )
        view.place(
            in: CGRect(x: 0, y: 0, width: 300, height: 24),
            atEnd: true
        )
        view.layout()
        let label = try #require(
            view.subviews.first { $0 is NSTextField } as? NSTextField
        )
        #expect(label.font?.familyName == Self.family)
    }

    /// The peek's header and titles all draw the
    /// shelf's family, at the peek's own reading size (#1946).
    @Test("The hover peek draws the family")
    func hoverPeek() throws {
        try #require(BarFont.isInstalled(Self.family))
        let body = BarPeekBody()
        _ = body.build(
            BarPeekContent(
                rows: [1, 2].map {
                    BarWindowRow(
                        window: WindowID($0),
                        pid: 1,
                        app: "Zed",
                        title: "Window \($0)",
                        icon: nil
                    )
                }
            ),
            shelf: Self.shelf
        )
        #expect(body.labels.count == 3)
        for field in body.labels {
            #expect(field.font?.familyName == Self.family)
        }
        let titles = body.labels.dropFirst()
        #expect(
            titles.allSatisfy {
                $0.font?.pointSize == BarPeekBody.Metrics.textSize
            }
        )
    }
}
