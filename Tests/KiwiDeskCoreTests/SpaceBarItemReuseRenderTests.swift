import AppKit
import Testing

@testable import KiwiDeskCore

/// **A Space switch's render keeps every item's views** (#1942),
/// end to end through `SpaceBarManager.sync`: the bar handed the
/// same app lists with another Space active reuses each item
/// view and each glyph and badge inside it.
@Suite("Space Bar render reuse (#1942)")
@MainActor
struct SpaceBarItemReuseRenderTests {
    init() { LiquidGlassGate.override = { false } }

    private static func bar(active: Int) -> SpaceBarManager.Bar {
        var style = SpaceBarLook()
        style.backgroundStyle = .plain
        let items = (1...3).map { n in
            SpaceBarOverlay.Item(
                space: SpaceID(String(n)),
                spaceGlyph: .text(String(n), tinted: true),
                apps: (1...2).map { k in
                    var app = SpaceBarItemView.App(
                        name: "App\(n)\(k)",
                        icon: icon,
                        glyph: nil,
                        focused: k == 1,
                        count: k,
                        windows: [WindowID(UInt32(n * 10 + k))]
                    )
                    app.sticky = k == 2
                    return app
                },
                active: n == active,
                after: .none
            )
        }
        return SpaceBarManager.Bar(
            display: barTitleDisplay,
            items: items,
            frontApp: nil,
            frontWindow: nil,
            strip: barTitleStrip,
            style: style,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
    }

    private static let icon = NSImage(size: NSSize(width: 16, height: 16))

    @Test("A switch re-renders without minting a view")
    func switchMintsNothing() throws {
        let manager = SpaceBarManager()
        manager.sync([Self.bar(active: 1)])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        let items = overlay.itemViews
        let inside = items.map(\.subviews)
        #expect(items.allSatisfy { $0.appViews.count == 2 })
        manager.sync([Self.bar(active: 2)])
        let keepsItems = SpaceBarItemReuseTests.same(
            overlay.itemViews,
            items
        )
        #expect(keepsItems)
        for (item, before) in zip(overlay.itemViews, inside) {
            let keepsViews = SpaceBarItemReuseTests.same(
                item.subviews,
                before
            )
            #expect(keepsViews)
        }
        #expect(overlay.itemViews[1].isActive)
    }
}
