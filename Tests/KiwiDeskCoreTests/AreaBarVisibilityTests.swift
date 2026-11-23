import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// An area may hide its bars (#3517 ruling 30): the sparse
/// `visibility_override` beside each bar's visibility, keyed by
/// area key, resolves in the one per-screen step, so an area whose
/// bars are hidden draws and reserves nothing while its neighbour
/// keeps them.
@Suite("Area bar visibility (#3517)", .serialized)
@MainActor
struct AreaBarVisibilityTests {
    private static let key = "Wide:3440x1440#1"

    @Test("an area's entry replaces the bar's visibility there")
    func entryResolvesForItsArea() {
        var settings = TilingSettings()
        settings.spaceBarStyle.visibility = .always
        settings.spaceBarStyle.visibilityOverride = [Self.key: .hidden]
        let area = settings.onScreen(Self.key)
        #expect(area.spaceBarStyle.visibility == .hidden)
        #expect(area.spaceBarStyle.visibilityOverride.isEmpty)
        #expect(
            settings.onScreen("Wide:3440x1440").spaceBarStyle.visibility
                == .always
        )
        #expect(settings.onScreen(nil).spaceBarStyle.visibility == .always)
        // Resolving again changes nothing.
        #expect(area.onScreen(Self.key) == area)
    }

    @Test("the App Bar's entry reaches only layouts that carry one")
    func appBarEntryKeepsLayoutsWithout() {
        var settings = TilingSettings()
        settings.appBarStyle.visibilityOverride = [Self.key: .hidden]
        let area = settings.onScreen(Self.key)
        for mode in LayoutMode.allCases {
            let stored = settings.appBarVisibility(in: mode)
            let shown = area.appBarVisibility(in: mode)
            #expect((stored == nil) == (shown == nil), "\(mode)")
            if stored != nil { #expect(shown == .hidden, "\(mode)") }
        }
        #expect(area.appBarStyle.visibilityOverride.isEmpty)
    }

    @Test("a hidden area reserves nothing; its neighbour reserves")
    func hiddenAreaReservesNothing() {
        let visible = CGRect(x: 0, y: 0, width: 1720, height: 1440)
        var settings = TilingSettings()
        settings.spaceBarStyle.visibility = .always
        settings.spaceBarStyle.reserve = true
        settings.kiwishelf.pocketVisibility = .hidden
        settings.spaceBarStyle.visibilityOverride = [Self.key: .hidden]
        let hidden = settings.layoutBounds(
            from: visible,
            mode: .bsp,
            on: Self.key,
            pocketAtRest: false
        )
        let shown = settings.layoutBounds(
            from: visible,
            mode: .bsp,
            on: "Wide:3440x1440",
            pocketAtRest: false
        )
        #expect(hidden == visible)
        #expect(shown.height < visible.height)
    }

    /// The Show master selects nothing while an area shows a bar
    /// its own way, since its pick clears that entry (ruling 32).
    @Test("an area's own Show makes the bars differ")
    func areaEntryDiffers() {
        var settings = TilingSettings()
        settings.setEveryBarVisibility(.always)
        #expect(settings.uniformBarVisibility == .always)
        settings.spaceBarStyle.visibilityOverride["Wide:3440x1440#1"] =
            .hidden
        #expect(settings.uniformBarVisibility == nil)
    }

    @Test("the map stays out of the JSON while empty and round-trips")
    func storedSparse() throws {
        var style = SpaceBarStyle()
        var app = AppBarStyle()
        let empty =
            try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(style)
            ) as? [String: Any]
        #expect(empty?["visibility_override"] == nil)
        style.visibilityOverride = [Self.key: .auto]
        app.visibilityOverride = [Self.key: .hidden]
        let back = try JSONDecoder().decode(
            SpaceBarStyle.self,
            from: JSONEncoder().encode(style)
        )
        let appBack = try JSONDecoder().decode(
            AppBarStyle.self,
            from: JSONEncoder().encode(app)
        )
        #expect(back.visibilityOverride == [Self.key: .auto])
        #expect(appBack.visibilityOverride == [Self.key: .hidden])
    }

    @Test(
        "a hidden area's shelf draws nothing through the drivers",
        .enabled(if: NSScreen.main != nil)
    )
    func hiddenAreaDrawsNoShelf() throws {
        guard let screen = NSScreen.screens.first,
            let display = screen.kiwiDisplay,
            let split = ScreenSplit.whole(
                width: Int(display.frame.width),
                height: Int(display.frame.height)
            ).splitting(0, .sideBySide)
        else { return }
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            GeometryUtils.axVisibleFrame(of: screen)
        }
        core.tiler.screenFrameAX = { KiwiCore.axFrame(of: $0) }
        core.state.apply(.displaysChanged([display]))
        var settings = core.tiler.settings
        settings.displayAreas = [display.fingerprint: split]
        settings.spaceBarStyle.visibility = .always
        settings.kiwishelf.liquidGlass = false
        core.tiler.settings = settings
        let areas = core.state.workspaces.placements(of: display.id)
        let right = try #require(areas.last)
        for (i, area) in areas.enumerated() {
            core.state.workspaces.assign(SpaceID(i + 1), to: area.id)
        }
        settings.spaceBarStyle.visibilityOverride = [
            right.key.description: .hidden
        ]
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        core.updateBars()
        let shown = core.spaceBars.overlaysForTesting.filter {
            $0.value.isVisible
        }
        #expect(Set(shown.keys) == [try #require(areas.first).id])
        let space = try #require(core.state.workspaces[SpaceID(2)])
        #expect(
            core.tiler.layoutBounds(on: screen, for: space)
                == core.tiler.visibleBounds(screen, for: space.id)
        )
    }
}
