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
    /// A live setup of `count` identical 27" screens.
    private func catalogSizes(_ count: Int) -> [CGSize] {
        [CGSize](
            repeating: CGSize(width: 2560, height: 1440),
            count: count
        )
    }

    /// Every layout that can reach a Presets list on some Mac:
    /// the hardware-agnostic workflows, plus the one `Starter`
    /// as each supported screen count derives it. The catalog
    /// stopped being a constant when the Starter began deriving
    /// from live screens (#678 Phase 4 pass 11).
    private func everyShippedLayout() -> [StandardLayout] {
        StandardProfiles.workflows
            + (1...3).map {
                StarterSetup.standardLayout(sizes: catalogSizes($0))
            }
    }

    @Test("Each shipped count has exactly one Standard")
    func oneStandardPerCount() {
        for count in 1...3 {
            let standards = StandardProfiles.layouts(
                for: count,
                sizes: catalogSizes(count)
            )
            .filter(\.isStandard)
            #expect(standards.count == 1)
        }
    }

    @Test("Layouts only address screens they plan for")
    func positionsWithinPlan() {
        for layout in everyShippedLayout() {
            for position in layout.spaceScreens.values {
                #expect(position >= 0)
                #expect(position < layout.screenCount)
            }
        }
    }

    @Test("Sparse maps only name defined spaces")
    func sparseMapsWithinSpaces() {
        for layout in everyShippedLayout() {
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
            StandardProfiles.standard(for: 3)?.screenCount == 3
        )
        #expect(
            StandardProfiles.standard(for: 4)?.screenCount == 4
        )
        // Past the family's largest count, the largest smaller one.
        #expect(
            StandardProfiles.standard(for: 5)?.screenCount == 4
        )
        #expect(
            StandardProfiles.standard(for: 9)?.screenCount
                == StandardProfiles.largestCount
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
        // Developer's one-screen plan: Stack · Scrolling · Grid ·
        // Monocle (#3294).
        #expect(composed.spaceModes[SpaceID(1)] == .stack)
        #expect(composed.spaceModes[SpaceID(2)] == .scrolling)
        for space in composed.spaces {
            #expect(composed.assignment[space] == DisplayID(1))
        }
    }

    /// An unpinned Space with no role keeps the screen the
    /// pre-#3294 Standards placed it on, whatever the preset family
    /// plans (#3294): two screens 1–4 / 5–8, the third screen 8–10,
    /// a fifth screen the next number past 10.
    @Test("the placement fallback keeps the old plan")
    func fallbackKeepsTheOldPlan() {
        let two = ProfileComposition.fallbackAssignment(
            displays: displays(2),
            mainID: DisplayID(1)
        )
        #expect(two[SpaceID(4)] == DisplayID(1))
        #expect(two[SpaceID(5)] == DisplayID(2))
        #expect(two[SpaceID(8)] == DisplayID(2))
        #expect(two[SpaceID(9)] == nil)
        let five = ProfileComposition.fallbackAssignment(
            displays: displays(5),
            mainID: DisplayID(1)
        )
        #expect(five[SpaceID(7)] == DisplayID(2))
        #expect(five[SpaceID(10)] == DisplayID(3))
        #expect(five[SpaceID(11)] == DisplayID(4))
        #expect(five[SpaceID(12)] == DisplayID(5))
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

    /// The 4-screen Standard (8 Spaces) plus screen 5, which takes
    /// the starter's single-Space rule: on a desktop-class screen
    /// the first of Grid · Stack · BSP · Scrolling placed least.
    @Test("an extra screen gets one Space by the single-Space rule")
    func extraScreenFill() throws {
        let composed = try #require(
            ProfileComposition.compose(
                displays: displays(5),
                mainID: DisplayID(1)
            )
        )
        #expect(composed.sourceName == "Developer")
        #expect(composed.spaces.count == 9)
        #expect(composed.spaceModes[SpaceID(9)] == .bsp)
        #expect(composed.assignment[SpaceID(9)] == DisplayID(5))
    }

    /// Beside an ultrawide a non-ultrawide extra screen never
    /// scrolls (#1662); a laptop leads Monocle.
    @Test("an extra screen beside an ultrawide never scrolls")
    func extraScreenClamp() {
        let unplaced: [LayoutMode] = [.grid, .stack, .bsp]
        #expect(
            ProfileComposition.extraScreenMode(
                .desktop,
                placed: unplaced,
                besideUltrawide: false
            ) == .scrolling
        )
        #expect(
            ProfileComposition.extraScreenMode(
                .desktop,
                placed: unplaced,
                besideUltrawide: true
            ) == .monocle
        )
        #expect(
            ProfileComposition.extraScreenMode(
                .laptop,
                placed: [],
                besideUltrawide: false
            ) == .monocle
        )
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
