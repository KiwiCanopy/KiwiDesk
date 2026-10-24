import AppKit
import Testing

@testable import KiwiDeskCore

/// The switch hands the plates the shelf's Fill while "Tint KiwiHub
/// and plates" is on, and nothing while it is off (#2569 ▸ Ruling).
extension SpaceSlideSwitchTests {
    @Test(
        "the plates take the Fill under the toggle",
        .enabled(if: NSScreen.main != nil),
        arguments: [true, false]
    )
    func platesTakeTheFill(tinted: Bool) throws {
        let (core, _) = try makeCore(slide: true)
        core.tiler.settings.kiwishelf.tintHubAndPlates = tinted
        core.tiler.settings.kiwishelf.fillFade = 40
        core.execute("focus_space", args: [.string("2")])
        defer { core.spaceSlide.end() }
        let play = try #require(core.spaceSlide.play)
        #expect(
            play.tint
                == (tinted ? core.tiler.settings.kiwishelf.glassFill : nil)
        )
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
        #expect(try #require(core.spaceSlide.play).tint == nil)
    }
}
