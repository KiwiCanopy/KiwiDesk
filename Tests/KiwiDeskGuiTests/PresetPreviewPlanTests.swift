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

    /// The plan KEEPS an empty screen and the drawing drops it —
    /// the split that lets `PresetScreenCard` consume this plan
    /// (it draws an outline per screen, empty or not) while the
    /// sheet draws no heading over an empty row.
    @Test("an empty screen is kept in the plan, not in the drawing")
    func emptyScreensAreKeptButNotDrawn() {
        // Three screens, both spaces on the first: screens 1 and 2
        // plan nothing.
        let plan = PresetPreviewPlan(
            layout: layout(screens: 3, spaces: 2),
            liveSizes: nil
        )
        #expect(plan.groups.map(\.screen) == [0, 1, 2])
        #expect(plan.groups[1].slots.isEmpty)
        #expect(plan.groups[1].openingMode == nil)
        #expect(plan.drawnGroups.map(\.screen) == [0])
        #expect(plan.slots.count == 2)
    }

    /// `openingMode` is the FIRST slot's, which is what the card's
    /// glyph draws.
    ///
    /// Stated limit: this cannot discriminate a `min`/`sorted`
    /// slip, and an earlier docstring claimed it could.
    /// `spaces(onScreen:)` filters `plannedSpaces`, so a group's
    /// slots are ALWAYS in ascending plan order and no fixture can
    /// express the case (re-review, 2026-08-17). What it does
    /// discriminate is `first` vs a fixed space id, and vs the
    /// LAYOUT's first space rather than the screen's — screen 1's
    /// opener here is space 2, not space 1.
    @Test("a group opens in its first space's mode")
    func openingModeIsTheFirstSlot() {
        let plan = PresetPreviewPlan(
            layout: layout(
                screens: 2,
                spaces: 4,
                screensBySpace: ["2": 1, "3": 1],
                modes: ["2": .monocle, "3": .track]
            ),
            liveSizes: nil
        )
        #expect(plan.groups[1].slots.map(\.space) == ["2", "3"])
        #expect(plan.groups[1].openingMode == .monocle)
        #expect(plan.groups[0].openingMode == .bsp)
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
                plan.drawnGroups.map(\.screen)
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

    // MARK: - One derivation, not two

    /// `PresetScreenCard` used to hold its own `spaces(on:)`,
    /// `openingMode(_:)` and `shape(of:)`, and an agreement test
    /// lived here requiring the two to answer alike on every
    /// shipped preset. Both #859 reviewers found that test could
    /// not see the card's half — the card's `shape(of:)` was
    /// `private` and the test recomputed `ScreenClass.of(...)`
    /// itself — so it is GONE rather than repaired: the card now
    /// consumes this plan, and a structural single derivation
    /// needs no agreement assertion.
    ///
    /// What replaces it is a needle, because the thing worth
    /// pinning is now "the card consumes the plan" and that is a
    /// wiring claim: `ProfilesGateWiringTests` holds it, keyed on
    /// the card's own use site.
    @Test("the plan resolves each screen's shape once")
    func shapeIsResolvedPerScreen() throws {
        let laptop = try #require(Self.sizes[.laptop])
        let ultrawide = try #require(Self.sizes[.ultrawide])
        // The one copy answers per POSITION, so two screens of
        // different shapes resolve apart — the property a shared
        // helper has to have and a duplicated one can lose.
        #expect(
            PresetPreviewPlan.shape(
                of: 0,
                in: [laptop, ultrawide]
            ) == .laptop
        )
        #expect(
            PresetPreviewPlan.shape(
                of: 1,
                in: [laptop, ultrawide]
            ) == .ultrawide
        )
        // Past the end, and with no hardware at all.
        #expect(PresetPreviewPlan.shape(of: 2, in: [laptop]) == nil)
        #expect(PresetPreviewPlan.shape(of: 0, in: nil) == nil)
        #expect(PresetPreviewPlan.shape(of: 0, in: []) == nil)
    }
}
