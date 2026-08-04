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
        track.limit = 4
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

    /// `fieldCapacity` (#678 8b, the `N of M set` denominator) is
    /// set-independent: a full override's capacity equals its field
    /// count, and an empty override's capacity equals the full
    /// one's — so `M` never moves as the user sets fields.
    @Test("fieldCapacity is the total field count, set or not")
    func capacityIsTotalFields() {
        for (name, full) in Self.fullFixtures() {
            let declared = fieldNames(full).count
            #expect(
                full.fieldCapacity == declared,
                Comment(
                    rawValue:
                        "\(name): capacity \(full.fieldCapacity), "
                        + "declared \(declared)"
                )
            )
            // A full override sets every field, so capacity ==
            // count there; the empty twin must report the SAME
            // capacity though its count is zero.
            let empty = type(of: full).init()
            #expect(
                empty.fieldCapacity == full.fieldCapacity,
                Comment(
                    rawValue:
                        "\(name): empty capacity drifted from full"
                )
            )
        }
    }

    /// `LayoutMode.overrideFieldCapacity` reads the layout's own
    /// override struct, and Floating — which has no override —
    /// reports zero, which is what suppresses the header fraction.
    @Test("LayoutMode capacity matches its override struct")
    func modeCapacityMatchesStruct() {
        #expect(
            LayoutMode.bsp.overrideFieldCapacity
                == BspOverride().fieldCapacity
        )
        #expect(
            LayoutMode.stack.overrideFieldCapacity
                == StackOverride().fieldCapacity
        )
        #expect(
            LayoutMode.scrolling.overrideFieldCapacity
                == ScrollingOverride().fieldCapacity
        )
        #expect(
            LayoutMode.grid.overrideFieldCapacity
                == GridOverride().fieldCapacity
        )
        #expect(
            LayoutMode.monocle.overrideFieldCapacity
                == MonocleOverride().fieldCapacity
        )
        #expect(
            LayoutMode.track.overrideFieldCapacity
                == TrackOverride().fieldCapacity
        )
        #expect(LayoutMode.floating.overrideFieldCapacity == 0)
    }
}
