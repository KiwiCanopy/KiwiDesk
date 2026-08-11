import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

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
            // Unlisted spaces only: a preset that DECLARES bsp is
            // allowed to, and `declaredModesWin` requires it.
            for space in layout.plannedSpaces
            where layout.spaceModes[space] == nil {
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
    /// The CARD's accessor against the composed mode, which is
    /// the parity `PresetScreenCard`'s docstring claims and the
    /// only thing that observes what it actually passes.
    ///
    /// The sweep above compares the plan to the composer with a
    /// shape supplied by the test; this compares what the view
    /// resolves to what the apply path produces. They fail apart:
    /// a card that stops threading the live shape reds only here.
    @Test("the appliable card names the layout Apply produces")
    func cardAgreesWithApply() throws {
        let laptop = CGSize(width: 1728, height: 1117)
        let wide = CGSize(width: 3440, height: 1440)
        for layout in StandardProfiles.workflows
        where layout.screenCount == 2 {
            let sizes = [laptop, wide]
            let displays = sizes.enumerated().map { index, size in
                Display(
                    id: DisplayID(UInt32(index + 1)),
                    name: "S\(index)",
                    frame: CGRect(
                        x: CGFloat(index) * 4000,
                        y: 0,
                        width: size.width,
                        height: size.height
                    )
                )
            }
            let composed = try #require(
                ProfileComposition.compose(
                    layout: layout,
                    displays: displays,
                    mainID: displays.first?.id
                )
            )
            for position in 0..<layout.screenCount {
                let drawn = layout.openingMode(
                    onScreen: position,
                    screens: layout.screenCount,
                    on: ScreenClass.of(sizes[position])
                )
                let applied =
                    layout
                    .spaces(
                        onScreen: position,
                        screens: layout.screenCount
                    )
                    .first
                    .map { composed.spaceModes[$0] ?? .bsp }
                #expect(
                    drawn == applied,
                    Comment(
                        rawValue:
                            "\(layout.name) screen \(position): "
                            + "the card would draw "
                            + "\(String(describing: drawn)) and "
                            + "Apply produces "
                            + "\(String(describing: applied))"
                    )
                )
            }
        }
    }

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
