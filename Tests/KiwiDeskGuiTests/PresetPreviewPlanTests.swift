import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// What the preset preview sheet decides to draw (#859).
///
/// The suite is written to two rules this repo has already paid
/// for. **A guard that restates the formula it guards passes on a
/// literal forever**, so the expectations below are written out
/// against fixtures the app does not ship rather than recomputed
/// from the accessors production calls. And **a sweep can guard a
/// clause it never executes**, so the parameter swept is `shape` —
/// the one that SELECTS the fallback branch inside
/// `StandardLayout.mode(of:on:)` — and both arms are required to
/// have fired.
@Suite("Preset preview plan")
struct PresetPreviewPlanTests {
    // MARK: - Fixtures

    private func layout(
        screens: Int,
        spaces: Int,
        screensBySpace: [SpaceID: Int] = [:],
        modes: [SpaceID: LayoutMode] = [:],
        gap: Double = 8
    ) -> StandardLayout {
        var settings = TilingSettings()
        settings.gapsGlobal = .uniform(gap)
        return StandardLayout(
            name: "Fixture",
            screenCount: screens,
            spaceCount: spaces,
            spaceModes: modes,
            spaceScreens: screensBySpace,
            isStandard: false,
            settings: settings
        )
    }

    /// One size per `ScreenClass`, with the class PINNED rather
    /// than inherited (tests.md #660): a fixture that assumes a
    /// size still lands in the class it was chosen for re-derives
    /// its own expectation the day a threshold moves.
    private static let sizes: [ScreenClass: CGSize] = [
        .laptop: CGSize(width: 1728, height: 1117),
        .desktop: CGSize(width: 2560, height: 1440),
        .ultrawide: CGSize(width: 3440, height: 1440),
        .pivoted: CGSize(width: 1440, height: 2560),
    ]

    @Test("every screen class has a pinned representative size")
    func fixtureSizesAreThatClass() throws {
        // Fails loudly if a threshold moves under the fixtures,
        // rather than letting the sweeps below quietly test one
        // class four times.
        #expect(Self.sizes.count == ScreenClass.allCases.count)
        for shape in ScreenClass.allCases {
            let size = try #require(Self.sizes[shape])
            #expect(ScreenClass.of(size) == shape)
        }
    }

    // MARK: - The plan

    /// Written out, not recomputed: three spaces over two screens
    /// with one space pinned to the second and one mode declared.
    @Test("groups carry their screen's spaces in plan order")
    func groupsFollowThePlan() {
        let plan = PresetPreviewPlan(
            layout: layout(
                screens: 2,
                spaces: 3,
                screensBySpace: ["3": 1],
                modes: ["2": .monocle]
            ),
            liveSizes: nil
        )
        #expect(plan.groups.map(\.screen) == [0, 1])
        #expect(plan.groups[0].slots.map(\.space) == ["1", "2"])
        #expect(plan.groups[1].slots.map(\.space) == ["3"])
        // Space 2 is declared; 1 and 3 are not, and with no
        // hardware in hand the historic bsp stands for both.
        #expect(plan.groups[0].slots.map(\.mode) == [.bsp, .monocle])
        #expect(plan.groups[1].slots.map(\.mode) == [.bsp])
        #expect(plan.slots.map(\.space) == ["1", "2", "3"])
    }

    /// The trap-2 sweep: `shape` is what picks the fallback arm, so
    /// it is what gets swept — every class AND nil — and both arms
    /// must be observed firing.
    ///
    /// Two assertions per class, and the FIRST is the one that
    /// survives a mutation: an undeclared space resolves to
    /// something other than `bsp` whenever a shape is known, and
    /// to `bsp` exactly when it is not. No class can satisfy that
    /// by accident, `bsp` leading none of the four lists. The
    /// equality against `shape.layouts.first` beside it is a
    /// precision check and would pass on a mirror by itself —
    /// which is why it is not alone.
    @Test("an undeclared mode follows the screen, never bsp")
    func undeclaredModeFollowsTheScreen() throws {
        let plan = layout(screens: 1, spaces: 2, modes: ["2": .grid])
        var withShape = 0
        var withoutShape = 0

        for shape in ScreenClass.allCases {
            let size = try #require(Self.sizes[shape])
            let drawn = PresetPreviewPlan(
                layout: plan,
                liveSizes: [size]
            )
            let undeclared = try #require(
                drawn.slots.first { $0.space == "1" }
            )
            #expect(undeclared.mode != .bsp)
            #expect(undeclared.mode == shape.layouts.first)
            // The declared one is untouched by the shape.
            #expect(
                drawn.slots.first { $0.space == "2" }?.mode == .grid
            )
            withShape += 1
        }

        for liveSizes in [nil, []] as [[CGSize]?] {
            let drawn = PresetPreviewPlan(
                layout: plan,
                liveSizes: liveSizes
            )
            #expect(
                drawn.slots.first { $0.space == "1" }?.mode == .bsp
            )
            withoutShape += 1
        }

        // Neither arm may pass by never running.
        #expect(withShape == ScreenClass.allCases.count)
        #expect(withoutShape == 2)
    }

    /// A `liveSizes` shorter than the screen count resolves the
    /// screens it covers and leaves the rest as plans — the bounds
    /// check, swept at the boundary rather than assumed.
    @Test("a short live-size list resolves only what it covers")
    func shortLiveSizesResolvePerScreen() throws {
        let laptop = try #require(Self.sizes[.laptop])
        let plan = PresetPreviewPlan(
            layout: layout(
                screens: 2,
                spaces: 2,
                screensBySpace: ["2": 1]
            ),
            liveSizes: [laptop]
        )
        #expect(plan.groups[0].slots[0].mode != .bsp)
        #expect(plan.groups[1].slots[0].mode == .bsp)
    }

    // MARK: - Screens with nothing on them

    @Test("a screen the preset plans nothing for is not drawn")
    func emptyScreensAreOmitted() {
        // Three screens, both spaces on the first: screens 1 and 2
        // plan nothing, so they draw no heading over no tiles.
        let plan = PresetPreviewPlan(
            layout: layout(screens: 3, spaces: 2),
            liveSizes: nil
        )
        #expect(plan.groups.map(\.screen) == [0])
    }

    /// The omission above is only safe while no shipped preset has
    /// an empty screen. This is what makes a future one a decision
    /// rather than a silent gap in the sheet.
    @Test("every shipped preset fills every screen it plans for")
    func everyShippedPresetFillsEveryScreen() {
        var checked = 0
        for layout in StandardProfiles.workflows {
            let plan = PresetPreviewPlan(
                layout: layout,
                liveSizes: nil
            )
            #expect(
                plan.groups.map(\.screen)
                    == Array(0..<layout.screenCount),
                Comment(
                    rawValue:
                        "\(layout.name) leaves a screen empty — "
                        + "the sheet would draw a heading with no "
                        + "tiles under it"
                )
            )
            #expect(plan.slots.count == layout.spaceCount)
            checked += 1
        }
        #expect(checked == StandardProfiles.workflows.count)
        #expect(checked > 0)
    }

    @Test("a negative screen count draws nothing")
    func negativeScreenCountDrawsNothing() {
        let plan = PresetPreviewPlan(
            layout: layout(screens: -3, spaces: 4),
            liveSizes: nil
        )
        #expect(plan.groups.isEmpty)
        #expect(plan.slots.isEmpty)
    }

    // MARK: - The card and the sheet answer alike

    /// The pair `PresetPreviewPlan`'s docstring promises instead of
    /// sharing a helper: the sheet's first mode on each screen is
    /// the mode the card draws a glyph for.
    ///
    /// It is not a tautology — the plan derives its own
    /// `ScreenClass` from `liveSizes` while this drives
    /// `openingMode` with the shape stated here, so the sub-diff
    /// mutation that matters (the plan passing `nil` and drawing a
    /// plan where the card draws hardware) reds it.
    @Test("the sheet's first mode is the card's glyph")
    func theCardAndTheSheetAgree() throws {
        let laptop = try #require(Self.sizes[.laptop])
        let desktop = try #require(Self.sizes[.desktop])
        var compared = 0
        for layout in StandardProfiles.workflows {
            let live = Array(
                repeating: [laptop, desktop],
                count: layout.screenCount
            )
            .flatMap { $0 }
            .prefix(layout.screenCount)
            let sizes = Array(live)
            let plan = PresetPreviewPlan(
                layout: layout,
                liveSizes: sizes
            )
            for group in plan.groups {
                let card = layout.openingMode(
                    onScreen: group.screen,
                    screens: layout.screenCount,
                    on: ScreenClass.of(sizes[group.screen])
                )
                #expect(group.slots.first?.mode == card)
                compared += 1
            }
        }
        #expect(compared > StandardProfiles.workflows.count)
    }
}
