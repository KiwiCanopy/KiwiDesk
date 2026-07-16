import Foundation
import Testing

@testable import KiwiDeskCore

/// Guards `SpaceLayoutOverride.fieldCount` (#290): the reflective
/// count that drives the `Overrides…` button tally and the
/// dormant-layout disclosure. For each override family a fully
/// populated fixture must report a count equal to its declared
/// field number, and an empty override must report zero.
///
/// `expectAllChanged` makes each fixture forget-proof: add a
/// field to an override and leave the fixture short, and the
/// fixture-exhaustiveness check goes red before the count check —
/// so the count guard can't silently pass on a stale fixture.
@Suite("Per-space override fieldCount (#290)")
struct SpaceOverrideFieldCountTests {
    /// A fully populated instance of every override family, paired
    /// with the family name for readable failures.
    private static func fullFixtures() -> [(String, any SpaceLayoutOverride)] {
        var bsp = BspOverride()
        bsp.strategy = .alternating
        bsp.splitRatioH = 0.6
        bsp.splitRatioV = 0.4

        var stack = StackOverride()
        stack.masterCount = 2
        stack.masterRatio = 0.55
        stack.overflowStyle = .cascadeAll
        stack.masterOrientation = .horizontal
        stack.stackPosition = .left

        var scrolling = ScrollingOverride()
        scrolling.slotSize = .points(320)
        scrolling.anchor = .end
        scrolling.orientation = .vertical

        var grid = GridOverride()
        grid.type = .rigid
        grid.fillEmptySpace = true
        grid.splitDirection = .vertical
        grid.columns = 3
        grid.rows = 2
        grid.autoSize = true

        var monocle = MonocleOverride()
        monocle.orientation = .vertical

        var track = TrackOverride()
        track.axis = .horizontal
        track.autoTracks = true
        track.count = 4
        track.overflowStyle = .cascadeAll

        return [
            ("Bsp", bsp), ("Stack", stack), ("Scrolling", scrolling),
            ("Grid", grid), ("Monocle", monocle), ("Track", track),
        ]
    }

    @Test("A full override counts every field")
    func fullCountsAllFields() {
        for (name, over) in Self.fullFixtures() {
            // The fixture must actually set every field — a new
            // field left unset trips here before the count check
            // below can silently pass on a stale fixture.
            expectAllChanged(over, from: type(of: over).init())
            let declared = fieldNames(over).count
            #expect(
                over.fieldCount == declared,
                "\(name): fieldCount \(over.fieldCount), declared \(declared)"
            )
        }
    }

    @Test("An empty override counts zero, matching isEmpty")
    func emptyCountsZero() {
        for (name, over) in [
            ("Bsp", BspOverride() as any SpaceLayoutOverride),
            ("Stack", StackOverride()),
            ("Scrolling", ScrollingOverride()),
            ("Grid", GridOverride()),
            ("Monocle", MonocleOverride()),
            ("Track", TrackOverride()),
        ] {
            #expect(over.fieldCount == 0, "\(name) empty count")
            #expect(over.isEmpty, "\(name) empty flag")
        }
    }

    @Test("A partial override counts only the set fields")
    func partialCountsSetFields() {
        var grid = GridOverride()
        grid.columns = 3
        #expect(grid.fieldCount == 1)
        grid.rows = 2
        #expect(grid.fieldCount == 2)
        grid.autoSize = true
        #expect(grid.fieldCount == 3)
    }
}
