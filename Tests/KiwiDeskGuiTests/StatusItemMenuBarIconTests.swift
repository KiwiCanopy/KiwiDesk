import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Layout choice of the menu bar icon (#3532), the GUI half:
/// a screen Core hands with its layout is named with that layout
/// for VoiceOver ("Space 2, Stack layout"), tiling off after it,
/// and a screen with no layout keeps its bare name. Core's half is
/// `StatusSpaceMarkChoiceTests`. `.serialized`: names are matched
/// in English through the process-wide `LocalizationManager`.
@Suite("Status item menu bar icon name (#3532)", .serialized)
@MainActor
struct StatusItemMenuBarIconTests {
    private func screen(
        _ id: UInt32,
        x: CGFloat,
        space: String,
        layout: LayoutMode?,
        tilingOff: Bool = false
    ) -> StatusSpaceMark.Screen {
        var screen = StatusSpaceMark.Screen(
            display: Display(
                id: DisplayID(id),
                name: "\(id)",
                frame: CGRect(x: x, y: 0, width: 1000, height: 600)
            ),
            space: SpaceID(space),
            glyph: .symbol(layout?.symbol ?? "questionmark")
        )
        screen.layout = layout
        screen.tilingOff = tilingOff
        return screen
    }

    @Test("a layout glyph is named with its layout")
    func layoutIsNamed() {
        LocalizationManager.shared.select("en")
        let one = StatusSpaceMark(
            layer: nil,
            screens: [screen(7, x: 0, space: "2", layout: .stack)]
        )
        #expect(
            StatusItemController.spaceMarkName(one)
                == "KiwiDesk (Space 2, Stack layout)"
        )
    }

    @Test("tiling off follows the layout, in desk order")
    func tilingOffFollowsTheLayout() {
        LocalizationManager.shared.select("en")
        let two = StatusSpaceMark(
            layer: nil,
            screens: [
                screen(8, x: 1000, space: "5", layout: .bsp),
                screen(7, x: 0, space: "2", layout: .stack, tilingOff: true),
            ]
        )
        #expect(
            StatusItemController.spaceMarkName(two)
                == "KiwiDesk (Spaces 2, Stack layout, tiling off and "
                + "5, BSP layout)"
        )
        #expect(StatusItemController.markedGlyphs(two) == [true, false])
    }

    @Test("a screen with no layout keeps its bare name")
    func noLayoutKeepsTheName() {
        LocalizationManager.shared.select("en")
        let one = StatusSpaceMark(
            layer: nil,
            screens: [screen(7, x: 0, space: "2", layout: nil)]
        )
        #expect(
            StatusItemController.spaceMarkName(one)
                == "KiwiDesk (Space 2)"
        )
    }
}
