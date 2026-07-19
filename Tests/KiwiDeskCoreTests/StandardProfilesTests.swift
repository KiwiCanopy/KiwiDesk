import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private func display(
    _ id: UInt32,
    name: String,
    x: CGFloat
) -> Display {
    Display(
        id: DisplayID(id),
        name: name,
        frame: CGRect(x: x, y: 0, width: 1920, height: 1080)
    )
}

@Suite("Positional display ordering")
struct PositionalDisplaysTests {
    @Test("Main display leads regardless of position")
    func mainLeads() {
        let displays = [
            display(1, name: "Left", x: -1920),
            display(2, name: "Center", x: 0),
            display(3, name: "Right", x: 1920),
        ]
        let ordered = PositionalDisplays.ordered(
            displays,
            mainID: DisplayID(2)
        )
        #expect(ordered.map(\.name) == ["Center", "Left", "Right"])
    }

    @Test("Unknown main falls back to leftmost-first")
    func unknownMain() {
        let displays = [
            display(2, name: "Right", x: 1920),
            display(1, name: "Left", x: 0),
        ]
        let ordered = PositionalDisplays.ordered(
            displays,
            mainID: nil
        )
        #expect(ordered.map(\.name) == ["Left", "Right"])
    }

    @Test("Identical coordinates order by fingerprint")
    func deterministicTies() {
        let displays = [
            display(2, name: "B", x: 0),
            display(1, name: "A", x: 0),
        ]
        let ordered = PositionalDisplays.ordered(
            displays,
            mainID: nil
        )
        #expect(ordered.map(\.name) == ["A", "B"])
    }
}

@Suite("Standard layout catalog")
struct StandardCatalogTests {
    @Test("Each shipped count has exactly one Standard")
    func oneStandardPerCount() {
        for count in 1...3 {
            let standards = StandardProfiles.layouts(for: count)
                .filter(\.isStandard)
            #expect(standards.count == 1)
        }
    }

    @Test("Layouts only address screens they plan for")
    func positionsWithinPlan() {
        for layout in StandardProfiles.all {
            for position in layout.spaceScreens.values {
                #expect(position >= 0)
                #expect(position < layout.screenCount)
            }
        }
    }

    @Test("Sparse maps only name defined spaces")
    func sparseMapsWithinSpaces() {
        for layout in StandardProfiles.all {
            let defined = Set(
                (1...layout.spaceCount).map { SpaceID($0) }
            )
            #expect(
                Set(layout.spaceModes.keys)
                    .isSubset(of: defined)
            )
            #expect(
                Set(layout.spaceScreens.keys)
                    .isSubset(of: defined)
            )
        }
    }

    @Test("Standard fallback picks the closest smaller count")
    func closestStandard() {
        #expect(StandardProfiles.standard(for: 0) == nil)
        #expect(
            StandardProfiles.standard(for: 1)?.screenCount == 1
        )
        #expect(
            StandardProfiles.standard(for: 2)?.screenCount == 2
        )
        #expect(
            StandardProfiles.standard(for: 5)?.screenCount == 3
        )
    }
}

@Suite("Fallback composition")
struct ProfileCompositionTests {
    private func displays(_ count: Int) -> [Display] {
        (1...count).map { number in
            display(
                UInt32(number),
                name: "D\(number)",
                x: CGFloat(number - 1) * 1920
            )
        }
    }

    @Test("Single monitor composes the 1-screen Standard")
    func singleMonitor() throws {
        let composed = try #require(
            ProfileComposition.compose(
                displays: displays(1),
                mainID: DisplayID(1)
            )
        )
        #expect(composed.sourceName == "Developer")
        #expect(composed.spaces.count == 4)
        #expect(composed.spaceModes[SpaceID(1)] == .grid)
        #expect(composed.spaceModes[SpaceID(2)] == .stack)
        for space in composed.spaces {
            #expect(composed.assignment[space] == DisplayID(1))
        }
    }

    @Test("Every space and screen resolves (total function)")
    func totality() throws {
        for count in 1...6 {
            let composed = try #require(
                ProfileComposition.compose(
                    displays: displays(count),
                    mainID: DisplayID(1)
                )
            )
            // Space side: every space has a mode and a screen.
            for space in composed.spaces {
                #expect(composed.spaceModes[space] != nil)
                #expect(composed.assignment[space] != nil)
            }
            // Screen side: every display shows at least one
            // space.
            let used = Set(composed.assignment.values)
            #expect(
                used
                    == Set(
                        (1...count).map {
                            DisplayID(UInt32($0))
                        }
                    )
            )
        }
    }

    @Test("Extra screens each get one fresh monocle space")
    func monocleFill() throws {
        let composed = try #require(
            ProfileComposition.compose(
                displays: displays(5),
                mainID: DisplayID(1)
            )
        )
        // 3-screen Standard (10 spaces) + screens 4 and 5.
        #expect(composed.sourceName == "Command Center")
        #expect(composed.spaces.count == 12)
        #expect(composed.spaceModes[SpaceID(11)] == .monocle)
        #expect(composed.spaceModes[SpaceID(12)] == .monocle)
        #expect(composed.assignment[SpaceID(11)] == DisplayID(4))
        #expect(composed.assignment[SpaceID(12)] == DisplayID(5))
    }

    @Test("Positional mapping follows the main display")
    func mainAware() throws {
        // Main is physically on the right: spaces 1–4 must
        // land there, the left screen becomes "second".
        let two = [
            display(1, name: "Left", x: 0),
            display(2, name: "Right", x: 1920),
        ]
        let composed = try #require(
            ProfileComposition.compose(
                displays: two,
                mainID: DisplayID(2)
            )
        )
        #expect(composed.assignment[SpaceID(1)] == DisplayID(2))
        #expect(composed.assignment[SpaceID(5)] == DisplayID(1))
    }

    @Test("No displays composes nothing")
    func empty() {
        #expect(
            ProfileComposition.compose(
                displays: [],
                mainID: nil
            ) == nil
        )
    }
}
