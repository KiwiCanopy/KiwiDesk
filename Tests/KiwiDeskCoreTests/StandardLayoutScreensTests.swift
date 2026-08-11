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
        // `on: nil` is the plan-as-a-plan reading — no hardware
        // in hand, so the historic bsp answer stands.
        #expect(plan.mode(of: "1", on: nil) == .bsp)
        #expect(plan.mode(of: "2", on: nil) == .monocle)
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
        // Every layout that can reach a Presets list: the
        // hardware-agnostic workflows, plus the Starter as each
        // supported screen count derives it (#678 pass 11).
        let composerSize = CGSize(width: 1000, height: 800)
        let plans =
            StandardProfiles.workflows
            + (1...3).map { count in
                StarterSetup.standardLayout(
                    sizes: [CGSize](
                        repeating: composerSize,
                        count: count
                    )
                )
            }
        for plan in plans {
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
                        screens: plan.screenCount,
                        // The composer answers an unlisted mode
                        // from the display the space lands on, so
                        // the plan must be read against the same
                        // shape or the two disagree by
                        // construction (owner ruling,
                        // 2026-08-11).
                        on: ScreenClass.of(composerSize)
                    )
                        == planned.first.map {
                            composed.spaceModes[$0] ?? .bsp
                        }
                )
            }
        }
    }
}

/// The sparse-mode fallback follows the screen (owner ruling,
/// 2026-08-11).
@Suite("Sparse preset modes follow the screen")
struct SparseModeFallbackTests {
    private let laptop = CGSize(width: 1728, height: 1117)
    private let screen27 = CGSize(width: 2560, height: 1440)

    private func display(_ size: CGSize) -> Display {
        Display(
            id: DisplayID(1),
            name: "S",
            frame: CGRect(origin: .zero, size: size)
        )
    }

    /// The shipped presets that carry a sparse map, and the
    /// reason this ruling exists: `Minimalist` declares nothing
    /// for space 2 and `Focus Stack` nothing for space 3.
    @Test("a laptop never receives BSP from a sparse preset")
    func laptopNeverGetsBsp() throws {
        for layout in StandardProfiles.workflows
        where layout.screenCount == 1 {
            let composed = try #require(
                ProfileComposition.compose(
                    layout: layout,
                    displays: [display(laptop)],
                    mainID: DisplayID(1)
                )
            )
            for space in layout.plannedSpaces {
                // `?? .bsp` deliberately: `spaceModes` is
                // `[SpaceID: LayoutMode]`, so a bare `!= .bsp`
                // over the Optional PASSES on nil — a composer
                // that wrote no mode at all left this whole suite
                // green (guard-prover, 2026-08-11). The fallback
                // makes "wrote nothing" read as the thing it
                // resolves to at every consumer anyway.
                let mode = composed.spaceModes[space] ?? .bsp
                #expect(
                    mode != .bsp,
                    Comment(
                        rawValue:
                            "\(layout.name) put BSP on a laptop "
                            + "at space \(space.raw) — the one "
                            + "layout ScreenClass rules out there"
                    )
                )
            }
        }
        // Vacuity: a sparse preset must exist, or the sweep asks
        // nothing at all.
        #expect(
            StandardProfiles.workflows.contains {
                $0.screenCount == 1
                    && $0.spaceModes.count < $0.spaceCount
            }
        )
    }

    /// `try #require` in a throwing test, not `try?` behind a
    /// `guard … else { return }`: that shape swallows the
    /// failure and returns from a test having asserted nothing,
    /// so renaming the preset would retire this guard in silence
    /// (guard-prover, 2026-08-11).
    @Test("a declared mode is never overridden by the screen")
    func declaredModesWin() throws {
        let layout = try #require(
            StandardProfiles.workflows.first {
                $0.name == "Minimalist"
            }
        )
        #expect(!layout.spaceModes.isEmpty)
        for (space, mode) in layout.spaceModes {
            #expect(
                layout.mode(of: space, on: .laptop) == mode,
                "the screen overrode a declared mode"
            )
        }
    }

    /// Where the caller cannot know the hardware — a preset card
    /// drawing a three-screen plan on a one-screen Mac — the
    /// historic answer stands rather than an invented shape.
    @Test("an unknown screen keeps the historic bsp answer")
    func unknownScreenKeepsBsp() {
        let layout = StandardLayout(
            name: "T",
            screenCount: 1,
            spaceCount: 2,
            spaceModes: ["1": .grid],
            spaceScreens: [:],
            isStandard: false,
            settings: TilingSettings()
        )
        #expect(layout.mode(of: SpaceID("2"), on: nil) == .bsp)
        #expect(
            layout.mode(of: SpaceID("2"), on: .laptop) == .scrolling
        )
        #expect(
            layout.mode(of: SpaceID("2"), on: .desktop) == .grid
        )
    }
}
