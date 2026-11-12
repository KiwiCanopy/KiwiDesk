import AppKit
import Testing

@testable import KiwiDeskCore

/// The switch hands the plates the shelf's Fill while "Tint KiwiHub
/// and plates" is on — for their glass, or flat for their material
/// where no glass draws — and nothing while it is off (#2569).
extension SpaceSlideSwitchTests {
    @Test(
        "the plates take the Fill under the toggle",
        .enabled(if: NSScreen.main != nil),
        arguments: [true, false]
    )
    func platesTakeTheFill(tinted: Bool) throws {
        let (core, _) = try makeCore(slide: true)
        let before = LiquidGlassGate.override
        LiquidGlassGate.override = { false }
        defer { LiquidGlassGate.override = before }
        core.tiler.settings.kiwishelf.tintHubAndPlates = tinted
        core.tiler.settings.kiwishelf.fillFade = 40
        core.execute("focus_space", args: [.string("2")])
        defer { core.spaceSlide.end() }
        let play = try #require(core.spaceSlide.play)
        #expect(
            play.tint
                == (tinted ? core.tiler.settings.kiwishelf.glassFill : nil)
        )
        // On glass the Fill is the glass's, never a frost beside it.
        #expect(play.frost == nil)
    }

    /// A Fill without colour leaves the plates untinted, as the
    /// toggle off does (#2569 ▸ "No Colour").
    @Test(
        "plates take no tint from a Fill without colour",
        .enabled(if: NSScreen.main != nil)
    )
    func noColourLeavesThePlatesUntinted() throws {
        let (core, _) = try makeCore(slide: true)
        core.tiler.settings.kiwishelf.tintHubAndPlates = true
        core.tiler.settings.kiwishelf.fillColor = "#14201C00"
        core.execute("focus_space", args: [.string("2")])
        defer { core.spaceSlide.end() }
        let play = try #require(core.spaceSlide.play)
        #expect(play.tint == nil)
        #expect(play.frost == nil)
    }

    /// Reduce transparency stands the plates' glass down, and the
    /// Fill moves onto their material, opaque (#2569 ▸ amendment).
    @Test(
        "plates wear the Fill opaque under Reduce transparency",
        .enabled(if: NSScreen.main != nil)
    )
    func reducedTransparencyMovesTheFill() throws {
        let (core, _) = try makeCore(slide: true)
        let before = LiquidGlassGate.override
        LiquidGlassGate.override = { true }
        defer { LiquidGlassGate.override = before }
        core.tiler.settings.kiwishelf.tintHubAndPlates = true
        core.execute("focus_space", args: [.string("2")])
        defer { core.spaceSlide.end() }
        let play = try #require(core.spaceSlide.play)
        #expect(play.tint == nil)
        #expect(play.frost?.alpha == 1)
    }

    /// The plates follow KiwiHub's Liquid Glass leaf: off, the Fill
    /// is flat over their material at its own alpha, and off the
    /// toggle they wear none (#2569 ▸ amendment).
    @Test(
        "plates wear the Fill flat with KiwiHub's glass off",
        .enabled(if: NSScreen.main != nil),
        arguments: [true, false]
    )
    func leafOffWearsTheFillFlat(tinted: Bool) throws {
        let (core, _) = try makeCore(slide: true)
        let before = LiquidGlassGate.override
        LiquidGlassGate.override = { false }
        defer { LiquidGlassGate.override = before }
        core.tiler.settings.kiwishelf.tintHubAndPlates = tinted
        core.tiler.settings.shortcutPanelLiquidGlass = false
        core.execute("focus_space", args: [.string("2")])
        defer { core.spaceSlide.end() }
        let play = try #require(core.spaceSlide.play)
        #expect(play.tint == nil)
        let frost = core.tiler.settings.kiwishelf.frostFill(opaque: false)
        #expect(play.frost == (tinted ? frost : nil))
        #expect(frost.map { $0.alpha < 1 } == true)
    }
}
