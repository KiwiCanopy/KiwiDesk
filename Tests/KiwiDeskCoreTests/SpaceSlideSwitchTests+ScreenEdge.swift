import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The slide's axis per screen (#1948), split from
/// `SpaceSlideSwitchTests.swift` for the file ceiling.
extension SpaceSlideSwitchTests {
    /// The axis reads the Space Bar's edge as the switching
    /// screen has it, the bar's own edge still top.
    @Test(
        "a screen's own side edge slides the strip vertically",
        .enabled(if: NSScreen.main != nil)
    )
    func screenSideEdgeSlidesVertically() throws {
        let (core, _) = try makeCore(slide: true)
        let display = try #require(NSScreen.main?.kiwiDisplay)
        core.state.workspaces.upsertDisplay(display)
        core.tiler.settings.spaceBarStyle.edgeOverride = [
            display.fingerprint: .left
        ]
        #expect(core.tiler.settings.spaceBarStyle.edge == .top)
        core.execute("focus_space", args: [.string("2")])
        defer { core.spaceSlide.end() }
        #expect(core.spaceSlide.play?.axis == .vertical)
    }
}
