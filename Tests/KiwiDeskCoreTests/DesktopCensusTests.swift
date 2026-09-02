import Foundation
import Testing

@testable import KiwiDeskCore

/// The per-Desktop census value (#1146), built from injected
/// per-space lists and an owner map — no WindowServer.
@Suite("Desktop census")
struct DesktopCensusTests {
    /// Space 30 is CURRENT and non-user (a fullscreen space):
    /// never shown, never read.
    private let spaces: [NativeSpace] = [
        authoritySpace(1, display: "UUID-A", current: true),
        authoritySpace(4, display: "UUID-A"),
        authoritySpace(9, display: "UUID-A", isUser: false),
        authoritySpace(20, display: "UUID-B", current: true),
        authoritySpace(30, display: "UUID-C", current: true, isUser: false),
    ]

    /// Windows per space: `all` includes the parked ones.
    private func lister(
        _ table: [SkyLight.SpaceID: (all: [UInt32], up: [UInt32])]
    ) -> (SkyLight.SpaceID, Bool) -> [WindowID]? {
        { space, parked in
            guard let entry = table[space] else { return [] }
            return (parked ? entry.all : entry.up).map(WindowID.init)
        }
    }

    @Test("a window on a Desktop nobody shows is away")
    func awayOnUnshown() throws {
        let census = try #require(
            DesktopCensus.build(
                spaces: spaces,
                owners: [WindowID(7): 100, WindowID(8): 100],
                list: lister([1: ([8], [8]), 4: ([7], [7])])
            )
        )
        #expect(census.isAway(WindowID(7)))
        #expect(!census.isAway(WindowID(8)))
        #expect(census.hosts[WindowID(7)]?.space == 4)
        #expect(census.shown == [1, 20])
    }

    @Test("parked is hosted but not up")
    func parkedIsNotUp() throws {
        let census = try #require(
            DesktopCensus.build(
                spaces: spaces,
                owners: [WindowID(7): 100],
                list: lister([4: ([7], [])])
            )
        )
        #expect(census.hosts[WindowID(7)]?.isUp == false)
        #expect(census.isAway(WindowID(7)))
    }

    @Test("a window the owner map does not list is not a layer-0 window")
    func unownedIsSkipped() throws {
        let census = try #require(
            DesktopCensus.build(
                spaces: spaces,
                owners: [:],
                list: lister([4: ([7], [7])])
            )
        )
        #expect(census.hosts.isEmpty)
    }

    @Test("a non-user space hosts no away window")
    func systemSpaceIsNotRead() throws {
        let census = try #require(
            DesktopCensus.build(
                spaces: spaces,
                owners: [WindowID(7): 100],
                list: lister([9: ([7], [7])])
            )
        )
        #expect(census.hosts[WindowID(7)] == nil)
    }

    @Test(
        "a window listed on a shown and an unshown space keeps the shown host"
    )
    func shownHostWins() throws {
        let census = try #require(
            DesktopCensus.build(
                spaces: spaces,
                owners: [WindowID(7): 100],
                list: lister([4: ([7], [7]), 20: ([7], [7])])
            )
        )
        #expect(!census.isAway(WindowID(7)))
        #expect(census.hosts[WindowID(7)]?.space == 20)
    }

    /// The mirror fixture: the SHOWN space listed first, so a
    /// last-writer-wins builder would lose it.
    @Test("a shown host listed first is kept over a later unshown one")
    func shownHostListedFirstWins() throws {
        let census = try #require(
            DesktopCensus.build(
                spaces: spaces,
                owners: [WindowID(7): 100],
                list: lister([1: ([7], [7]), 4: ([7], [7])])
            )
        )
        #expect(!census.isAway(WindowID(7)))
        #expect(census.hosts[WindowID(7)]?.space == 1)
    }

    @Test("an unreadable space list is no census at all")
    func absentListIsNil() {
        let census = DesktopCensus.build(
            spaces: spaces,
            owners: [WindowID(7): 100],
        ) { _, _ in nil }
        #expect(census == nil)
    }
}
