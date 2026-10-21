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
    /// so its switch closes the Show group, after the master and its
    /// Each bar drawer, which no block gate greys — never in the Space
    /// Bar card (#2228, #761).
    @Test("the switch closes the Show group")
    func switchClosesTheShowGroup() throws {
        let show = BarsRowOrder.kiwishelfShow
        #expect(show.last == .spaceBar(.spaceCue))
        #expect(show.first == .kiwishelf(.visibility))
        let placement = SettingKey.spaceBar(.spaceCue).placement
        #expect(placement.container == .kiwishelf)
        #expect(placement.gate == .runtime(.luaOwnsConfig))
    }

    /// The Reveal row sits under Each bar, ahead of the Space cue,
    /// at rest rather than in the Style drawer (owner ruling,
    /// 2026-10-21).
    @Test("the Reveal row follows Each bar in the Show group")
    func revealFollowsEachBar() {
        let show = BarsRowOrder.kiwishelfShow
        #expect(show.dropFirst().first == .kiwishelf(.revealStyle))
        #expect(
            !BarsRowOrder.kiwishelfStyle.contains(.kiwishelf(.revealStyle))
        )
        let placement = SettingKey.kiwishelf(.revealStyle).placement
        #expect(placement.container == .kiwishelf)
        #expect(placement.gate == .runtime(.noBarHides))
    }
}
