import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// The Space cue's GUI half (#2143, #2228): the one spoken
/// sentence, a cue that never steps, and its switch's place under
/// the Space Bar's own.
@Suite("Space cue plate (#2143, #2228)")
@MainActor
struct SpaceCuePlateTests {
    private let cue = SpaceSwitchCue(
        display: DisplayID(1),
        space: "2",
        mode: .grid
    )

    @Test("VoiceOver hears the Space and its layout")
    func spokenSentence() {
        LocalizationManager.shared.select("en")
        #expect(CuePlateModel.spoken(.space(cue)) == "Space 2, Grid")
    }

    /// Only a layout cue over a shown one moves (#2144); a Space
    /// cue appears at once, over itself or a layout cue.
    @Test("a Space cue never steps")
    func spaceCueNeverSteps() {
        let mode = CuePlateModel.Content.mode(
            ModeCycleCue(display: DisplayID(1), cycle: [.bsp], current: .bsp)
        )
        #expect(
            !CuePlateModel.steps(
                from: .space(cue),
                visible: true,
                to: .space(cue)
            )
        )
        #expect(
            !CuePlateModel.steps(from: mode, visible: true, to: .space(cue))
        )
    }

    /// The plate is for a screen the Space Bar does not draw on,
    /// so its switch sits directly under the bar's own in the Show
    /// group, which no block gate greys — never in the Space Bar card,
    /// which greys while the bar is off (#2228).
    @Test("the switch sits under the Space Bar's own")
    func switchSitsUnderTheSpaceBar() throws {
        let show = BarsRowOrder.kiwishelfShow
        let bar = try #require(
            show.firstIndex(of: .spaceBar(.spaceBarEnabled))
        )
        #expect(show.firstIndex(of: .spaceBar(.spaceCue)) == bar + 1)
        let placement = SettingKey.spaceBar(.spaceCue).placement
        #expect(placement.container == .kiwishelf)
        #expect(placement.gate == .runtime(.luaOwnsConfig))
    }
}
