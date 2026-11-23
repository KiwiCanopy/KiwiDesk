import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Each area of a split screen draws its own bars through the real
/// drivers (#3517 ruling 30): a Space Bar listing that area's
/// Spaces with its shown one active, its shelf inside the area, a
/// stacked lower area's top bar on its own top edge, and the Pocket
/// resting and reserving in the lead area alone. Needs a host
/// screen, whose own frames every expectation is measured against.
@Suite(
    "Area shelf drivers (#3517)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct AreaShelfDriverTests {
    /// A core on the primary screen split by `edit`, one Space per
    /// area in reading order, the Space Bar Always on top.
    private func makeCore(
        _ edit: (ScreenSplit) -> ScreenSplit?,
        tune: (inout TilingSettings) -> Void = { _ in }
    ) -> (KiwiCore, NSScreen, [Placement])? {
        guard let screen = NSScreen.screens.first,
            let display = screen.kiwiDisplay,
            let split = edit(
                ScreenSplit.whole(
                    width: Int(display.frame.width),
                    height: Int(display.frame.height)
                )
            )
        else { return nil }
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            GeometryUtils.axVisibleFrame(of: screen)
        }
        core.tiler.screenFrameAX = { KiwiCore.axFrame(of: $0) }
        core.state.apply(.displaysChanged([display]))
        var settings = core.tiler.settings
        settings.displayAreas = [display.fingerprint: split]
        settings.spaceBarStyle.visibility = .always
        settings.spaceBarStyle.edge = .top
        settings.kiwishelf.liquidGlass = false
        tune(&settings)
        core.tiler.settings = settings
        let areas = core.state.workspaces.placements(of: display.id)
        for (i, area) in areas.enumerated() {
            core.state.workspaces.assign(SpaceID(i + 1), to: area.id)
        }
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        return (core, screen, areas)
    }

    private func frame(
        of area: Placement,
        in core: KiwiCore,
        on screen: NSScreen
    ) -> CGRect {
        core.shelfFrame(
            of: area,
            visible: GeometryUtils.axVisibleFrame(of: screen),
            on: screen
        )
    }

    @Test("each area draws its own Space Bar for its own Space")
    func sideBySideAreasDrawTheirBars() throws {
        let (core, screen, areas) = try #require(
            makeCore { $0.splitting(0, .sideBySide) }
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        #expect(areas.count == 2)
        let overlays = core.spaceBars.overlaysForTesting
        #expect(Set(overlays.keys) == Set(areas.map(\.id)))
        let strips = core.spaceBars.shownStrips.map(\.strip)
        #expect(strips.count == 2)
        for (i, area) in areas.enumerated() {
            let rect = frame(of: area, in: core, on: screen)
            // The area's bar stands inside the area, on its top.
            #expect(
                strips.contains {
                    $0.minX >= rect.minX - 0.5 && $0.maxX <= rect.maxX + 0.5
                        && abs($0.minY - rect.minY) < 0.5
                }
            )
            let items = core.spaceBarItems(
                placement: area.id,
                style: core.tiler.settings.spaceBarLook
            )
            #expect(items.map(\.space) == [SpaceID(i + 1)])
            #expect(items.first?.active == true)
        }
        // One shelf per area on the top edge.
        let keys = core.shelves.overlaysForTesting.keys
        #expect(Set(keys.map(\.placement)) == Set(areas.map(\.id)))
        #expect(keys.allSatisfy { $0.edge == .top })
    }

    @Test("a stacked lower area's top bar sits on its own top edge")
    func lowerAreaBarSitsMidScreen() throws {
        let (core, screen, areas) = try #require(
            makeCore { $0.splitting(0, .stacked) }
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let lower = frame(of: try #require(areas.last), in: core, on: screen)
        let strips = core.spaceBars.shownStrips.map(\.strip)
        #expect(strips.count == 2)
        #expect(strips.contains { abs($0.minY - lower.minY) < 0.5 })
        // Its Space lays out under its own strip, inside its area.
        let space = try #require(core.state.workspaces[SpaceID(2)])
        let bounds = core.tiler.layoutBounds(on: screen, for: space)
        #expect(bounds.minY > lower.minY + 1)
        #expect(bounds.maxY <= lower.maxY + 0.5)
    }

    @Test("the Pocket reserves its strip in the lead area alone")
    func pocketReservesInTheLeadArea() throws {
        let (core, screen, areas) = try #require(
            makeCore({ $0.splitting(0, .sideBySide) }) {
                $0.kiwishelf.pocketVisibility = .always
                $0.kiwishelf.pocketEdges.setEdge(.bottom)
            }
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        for (i, area) in areas.enumerated() {
            let space = try #require(core.state.workspaces[SpaceID(i + 1)])
            let bounds = core.tiler.layoutBounds(on: screen, for: space)
            let rect = core.tiler.visibleBounds(screen, for: space.id)
            #expect((bounds.maxY < rect.maxY - 1) == (i == 0), "\(area.id)")
        }
    }

    @Test("the Pocket's section stands in the lead area alone")
    func pocketDrawsInTheLeadArea() throws {
        let (core, screen, areas) = try #require(
            makeCore({ $0.splitting(0, .sideBySide) }) {
                $0.kiwishelf.pocketVisibility = .always
                $0.kiwishelf.pocketEdges.setEdge(.top)
            }
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let first = try #require(areas.first)
        let lead = frame(of: first, in: core, on: screen)
        let slot = try #require(core.pocketPlate.slots[first.display])
        #expect(slot.minX >= lead.minX - 0.5 && slot.maxX <= lead.maxX + 0.5)
    }

    @Test("an area that merged away drops its bars")
    func departedAreaRetires() throws {
        let (core, _, areas) = try #require(
            makeCore { $0.splitting(0, .sideBySide) }
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        #expect(core.spaceBars.overlaysForTesting.count == 2)
        var settings = core.tiler.settings
        settings.displayAreas = [:]
        core.tiler.settings = settings
        core.updateBars()
        let lead = try #require(areas.first).id
        #expect(Set(core.spaceBars.overlaysForTesting.keys) == [lead])
        #expect(
            Set(core.shelves.overlaysForTesting.keys.map(\.placement))
                == [lead]
        )
    }

    /// A float keeps clear of its own area's bar strips only, and
    /// of the Pocket's mark only in the lead area.
    @Test("a Space's float strips are its own area's")
    func floatStripsPerArea() throws {
        let (core, screen, areas) = try #require(
            makeCore({ $0.splitting(0, .sideBySide) }) {
                $0.kiwishelf.pocketVisibility = .always
                $0.kiwishelf.pocketEdges.setEdge(.bottom)
                // The right area's own edge: read for the screen,
                // its strip would be the screen's top one.
                let screen = $0.displayAreas.keys.first ?? ""
                $0.spaceBarStyle.edgeOverride["\(screen)#1"] = .left
            }
        )
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        for (i, area) in areas.enumerated() {
            let rect = frame(of: area, in: core, on: screen)
            let strips = core.reservedStrips(forSpace: SpaceID(i + 1))
            let edge: AppBarEdge = i == 0 ? .top : .left
            let bars = strips.filter { $0.edge == edge }
            #expect(bars.count == 1, "\(area.id)")
            #expect(
                bars.allSatisfy {
                    $0.strip.minX >= rect.minX - 0.5
                        && $0.strip.maxX <= rect.maxX + 0.5
                },
                "\(area.id)"
            )
            // The Pocket's mark rests in the lead area alone.
            #expect(
                strips.contains { $0.edge == .bottom } == (i == 0),
                "\(area.id)"
            )
        }
    }
}
