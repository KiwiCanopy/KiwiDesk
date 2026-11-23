import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiHub's Desktops side on a split screen (#3572 ruling 2): each
/// Desktop's lines grouped by area in reading order, each group's
/// own shown Space, the unfiled line last in no group, and the line
/// a whole-Desktop pick lands on (ruling 5). Display A unsplit with
/// Space 1; display B split side by side, Spaces 6 and 3 in its
/// left area (3 shown) and 4 and 5 in its right; B shows Desktop 20
/// and hides 21.
@Suite("Desktop overview by area (#3572)", .serialized)
@MainActor
struct DesktopOverviewAreaTests {
    private func makeCore() -> (KiwiCore, [PlacementID]) {
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        pinTwoDisplays()
        let core = makeAuthorityCore()
        let wide = Display(
            id: DisplayID(2),
            name: "B",
            frame: CGRect(x: 100, y: 0, width: 3440, height: 1440)
        )
        let split = ScreenSplit.whole(width: 3440, height: 1440)
            .splitting(0, .sideBySide)
        core.state.workspaces.setAreaSplits(
            split.map { [wide.fingerprint: $0] } ?? [:]
        )
        connectAuthority(core, [authorityDisplay(1, "A"), wide])
        let areas = core.state.workspaces.placements(of: wide.id)
            .map(\.id)
        core.state.workspaces.ensureSpace(SpaceID(1))
        core.state.workspaces.assign(SpaceID(1), to: DisplayID(1))
        // Created right before left, so creation order alone would
        // list the right area's Spaces first.
        for (space, area) in [(4, 1), (6, 0), (5, 1), (3, 0)]
        where areas.count > area {
            core.state.workspaces.ensureSpace(SpaceID(space))
            core.state.workspaces.assign(SpaceID(space), to: areas[area])
        }
        core.state.workspaces.activate(SpaceID(1))
        if let left = areas.first {
            core.state.workspaces.show(SpaceID(3), on: left)
        }
        return (core, areas)
    }

    private func split(
        _ overview: DesktopOverview
    ) throws -> DesktopOverview.Screen {
        try #require(overview.screens.first { $0.display == DisplayID(2) })
    }

    @Test("lines group by area in reading order, here marked")
    func groupsInReadingOrder() throws {
        defer { resetAuthorityOverrides() }
        let (core, areas) = makeCore()
        try #require(areas.count == 2)
        let screen = try split(core.desktopOverview(on: areas[1]))
        let shown = try #require(screen.desktops.first { $0.isShown })
        #expect(shown.spaces.map(\.space) == ["6", "3", "4", "5"])
        #expect(shown.areas.map(\.lines) == [0..<2, 2..<4])
        #expect(shown.areas.map(\.position) == [.left, .right])
        #expect(shown.areas.map(\.isHere) == [false, true])
        let keys = areas.compactMap {
            core.state.workspaces[placement: $0]?.key
        }
        #expect(shown.areas.map(\.key) == keys)
        // Each area marks the Space it shows, the left one's
        // picked, the right one's its first.
        #expect(
            shown.spaces.map(\.isShown) == [false, true, true, false]
        )
        // The unsplit screen has no groups.
        let plain = try #require(
            core.desktopOverview(on: areas[1]).screens.first {
                $0.display == DisplayID(1)
            }
        )
        #expect(plain.desktops.allSatisfy { $0.areas.isEmpty })
    }

    @Test("a hidden Desktop marks each area's filed Space")
    func hiddenMarksEachArea() throws {
        defer { resetAuthorityOverrides() }
        let (core, areas) = makeCore()
        try #require(areas.count == 2)
        let hidden = try #require(authoritySnapshot().key(of: 21))
        let keys = areas.compactMap {
            core.state.workspaces[placement: $0]?.key.description
        }
        try #require(keys.count == 2)
        core.desktopMemory.areaSpaces[hidden] = [
            keys[0]: SpaceID(6), keys[1]: SpaceID(5),
        ]
        let screen = try split(core.desktopOverview(on: areas[0]))
        let card = try #require(screen.desktops.first { !$0.isShown })
        #expect(
            card.spaces.map(\.isShown) == [true, false, false, true]
        )
    }

    /// The switch moves the cursor's area to the cursor and every
    /// other area to its own target (`areaSpaceTargets`), so an
    /// entry filed for the cursor's area is not what returns.
    @Test("a hidden card marks what the switch will show")
    func hiddenFollowsTheSwitch() throws {
        defer { resetAuthorityOverrides() }
        let (core, areas) = makeCore()
        try #require(areas.count == 2)
        let hidden = try #require(authoritySnapshot().key(of: 21))
        let keys = areas.compactMap {
            core.state.workspaces[placement: $0]?.key.description
        }
        try #require(keys.count == 2)
        core.desktopMemory.virtualSpaces[hidden] = SpaceID(5)
        core.desktopMemory.areaSpaces[hidden] = [
            keys[0]: SpaceID(6), keys[1]: SpaceID(4),
        ]
        let screen = try split(core.desktopOverview(on: areas[0]))
        let card = try #require(screen.desktops.first { !$0.isShown })
        #expect(
            card.spaces.map(\.isShown) == [true, false, false, true]
        )
    }

    /// Nothing filed: the switch takes a free Space for the lead
    /// area and a free one for the other, and the card marks those.
    @Test("a first visit marks the switch's free Spaces")
    func firstVisitFollowsTheSwitch() throws {
        defer { resetAuthorityOverrides() }
        let (core, areas) = makeCore()
        try #require(areas.count == 2)
        let screen = try split(core.desktopOverview(on: areas[0]))
        let card = try #require(screen.desktops.first { !$0.isShown })
        #expect(
            card.spaces.map(\.isShown) == [true, false, false, true]
        )
    }

    @Test("area ranges run in order and cover all but unfiled")
    func rangesCoverTheLines() throws {
        defer { resetAuthorityOverrides() }
        let (core, areas) = makeCore()
        try #require(areas.count == 2)
        var entry = AwayWindow(
            id: WindowID(41),
            pid: 900_300,
            appName: "A",
            appBundleID: nil,
            nativeSpace: 21
        )
        entry.isUp = true
        core.state.awayWindows[WindowID(41)] = entry
        let screen = try split(core.desktopOverview(on: areas[0]))
        for desktop in screen.desktops {
            var next = 0
            for area in desktop.areas {
                #expect(area.lines.lowerBound == next)
                next = area.lines.upperBound
            }
            let unfiled = desktop.spaces.last?.space == nil ? 1 : 0
            #expect(next == desktop.spaces.count - unfiled)
        }
        #expect(screen.desktops.contains { $0.spaces.last?.space == nil })
    }

    @Test("a Desktop pick lands on the here area's shown line")
    func landingLine() throws {
        defer { resetAuthorityOverrides() }
        let (core, areas) = makeCore()
        try #require(areas.count == 2)
        func landing(_ here: PlacementID?) throws -> Int {
            let screen = try split(core.desktopOverview(on: here))
            return try #require(
                screen.desktops.first { $0.isShown }
            ).landingLine
        }
        #expect(try landing(areas[1]) == 2)
        #expect(try landing(areas[0]) == 1)
        // Opened over another screen: the first area's.
        #expect(try landing(core.hub(1)) == 1)
    }

    @Test("the unfiled line stays last, in no area")
    func unfiledStaysLast() throws {
        defer { resetAuthorityOverrides() }
        let (core, areas) = makeCore()
        try #require(areas.count == 2)
        var entry = AwayWindow(
            id: WindowID(40),
            pid: 900_300,
            appName: "A",
            appBundleID: nil,
            nativeSpace: 21
        )
        entry.isUp = true
        core.state.awayWindows[WindowID(40)] = entry
        let screen = try split(core.desktopOverview(on: areas[0]))
        let card = try #require(screen.desktops.first { !$0.isShown })
        let last = try #require(card.spaces.last)
        #expect(last.space == nil)
        #expect(last.windows.map(\.id) == [WindowID(40)])
        #expect(card.area(of: card.spaces.count - 1) == nil)
        #expect(card.areas.last?.lines.upperBound == card.spaces.count - 1)
    }
}

extension KiwiCore {
    /// The area a test opens KiwiHub over on display `id`: its
    /// first area, the whole screen while it is not split (#3572).
    fileprivate func hub(_ id: UInt32) -> PlacementID {
        hubArea(DisplayID(id))
    }

    fileprivate func hubArea(_ display: DisplayID) -> PlacementID {
        state.workspaces.placementOrWhole(of: display)
    }
}
