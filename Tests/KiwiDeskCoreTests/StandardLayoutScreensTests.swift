import Foundation
import Testing

@testable import KiwiDeskCore

/// `StandardLayout`'s screen plan (#678 turn 13a) — the one copy
/// of two sparse fallbacks that `ProfileComposition.compose` and
/// the Settings preset card both read.
///
/// The point of these accessors is that the two readers cannot
/// answer differently, so the last test asserts exactly that
/// rather than trusting the refactor: it drives the composer over
/// fabricated displays and requires its assignment to agree with
/// `spaces(onScreen:screens:)` layout by layout.
@Suite("Standard layout screens")
struct StandardLayoutScreensTests {
    private func layout(
        screens: Int,
        spaces: Int,
        screensBySpace: [SpaceID: Int] = [:],
        modes: [SpaceID: LayoutMode] = [:]
    ) -> StandardLayout {
        StandardLayout(
            name: "Fixture",
            screenCount: screens,
            spaceCount: spaces,
            spaceModes: modes,
            spaceScreens: screensBySpace,
            isStandard: false,
            settings: TilingSettings()
        )
    }

    @Test("an unlisted space sits on the main display")
    func sparseScreenDefault() {
        let plan = layout(
            screens: 2,
            spaces: 3,
            screensBySpace: ["3": 1]
        )
        #expect(plan.screen(of: "1", screens: 2) == 0)
        #expect(plan.screen(of: "2", screens: 2) == 0)
        #expect(plan.screen(of: "3", screens: 2) == 1)
    }

    @Test("an unlisted mode is bsp")
    func sparseModeDefault() {
        let plan = layout(
            screens: 1,
            spaces: 2,
            modes: ["2": .monocle]
        )
        #expect(plan.mode(of: "1") == .bsp)
        #expect(plan.mode(of: "2") == .monocle)
    }

    /// A hand-edited layout planning past the displays it is
    /// given must not index off the end — the composer clamped
    /// defensively before this accessor existed, and the clamp
    /// moved here with it.
    @Test("a space planned past the last screen clamps")
    func clampsBeyondTheScreenList() {
        let plan = layout(
            screens: 3,
            spaces: 2,
            screensBySpace: ["1": 9, "2": -4]
        )
        #expect(plan.screen(of: "1", screens: 2) == 1)
        #expect(plan.screen(of: "2", screens: 2) == 0)
        // Degenerate: no screens at all resolves to 0 rather
        // than to a negative index.
        #expect(plan.screen(of: "1", screens: 0) == 0)
    }

    @Test("a screen with no spaces has no opening mode")
    func emptyScreenHasNoMode() {
        let plan = layout(screens: 2, spaces: 1)
        #expect(
            plan.openingMode(onScreen: 0, screens: 2) == .bsp
        )
        #expect(
            plan.openingMode(onScreen: 1, screens: 2) == nil
        )
    }

    @Test("a zero-space layout plans nothing")
    func zeroSpaces() {
        let plan = layout(screens: 1, spaces: 0)
        #expect(plan.plannedSpaces.isEmpty)
        #expect(plan.spaces(onScreen: 0, screens: 1).isEmpty)
        #expect(plan.openingMode(onScreen: 0, screens: 1) == nil)
    }

    /// The composer and the accessors agree, over every shipped
    /// layout — the invariant the preset card's picture rests on.
    /// A copy re-introduced beside the drawing would still pass
    /// the per-accessor tests above and fail here.
    @Test("the composer places spaces where the plan says")
    func composerAgreesWithThePlan() throws {
        for plan in StandardProfiles.all {
            let displays = (0..<plan.screenCount).map {
                index in
                Display(
                    id: DisplayID(UInt32(index + 1)),
                    name: "Screen \(index)",
                    frame: CGRect(
                        x: CGFloat(index) * 1000,
                        y: 0,
                        width: 1000,
                        height: 800
                    )
                )
            }
            let composed = try #require(
                ProfileComposition.compose(
                    layout: plan,
                    displays: displays,
                    mainID: displays.first?.id
                )
            )
            let ordered = PositionalDisplays.ordered(
                displays,
                mainID: displays.first?.id
            )
            for position in 0..<plan.screenCount {
                let planned = plan.spaces(
                    onScreen: position,
                    screens: plan.screenCount
                )
                let composedHere = planned.filter {
                    composed.assignment[$0] == ordered[position].id
                }
                #expect(
                    planned == composedHere,
                    Comment(
                        rawValue:
                            "\(plan.name) screen \(position): the "
                            + "composer and the plan disagree"
                    )
                )
                // And the mode each screen opens in.
                #expect(
                    plan.openingMode(
                        onScreen: position,
                        screens: plan.screenCount
                    )
                        == planned.first.map {
                            composed.spaceModes[$0] ?? .bsp
                        }
                )
            }
        }
    }
}
