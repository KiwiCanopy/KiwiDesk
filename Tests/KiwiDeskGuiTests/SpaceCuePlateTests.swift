import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// The Space cue's GUI half (#2143, #2524): the one spoken
/// sentence, a cue that never steps, and its picker's place in the
/// Animations card.
@Suite("Space cue plate (#2143, #2524)")
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

    /// The picker and the slide's pace lead the Animations card,
    /// above the window master, outside Reduce Motion's grey, and
    /// grey where init.lua owns the config (#2524) — never in the
    /// bars' Show group, where #2228 had its switch.
    @Test("the picker and its pace lead the Animations card")
    func pickerLeadsTheAnimationsCard() {
        #expect(
            Array(ColorsRowOrder.motionAtRest.prefix(3)) == [
                .colours(.spaceTransition),
                .colours(.spaceSlideDuration),
                .colours(.animationsMaster),
            ]
        )
        for key in [
            SettingKey.colours(.spaceTransition),
            .colours(.spaceSlideDuration),
        ] {
            let placement = key.placement
            #expect(placement.area == .coloursAndMotion)
            #expect(placement.container == .motion)
            #expect(placement.gate == .runtime(.luaOwnsConfig))
            #expect(placement.exemptFromContainerGate)
        }
        #expect(BarsRowOrder.kiwishelfShow.last == .kiwishelf(.revealStyle))
    }

    /// The rows' greys are wired: the picker off under Lua, the pace
    /// greyed off Slide as well (#2524).
    @Test("the greys are wired to the rows")
    func greysAreWired() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Looks"
            )
        func flat(_ name: String) throws -> String {
            try String(
                contentsOf: root.appendingPathComponent(name),
                encoding: .utf8
            ).filter { !$0.isWhitespace }
        }
        let rows = try flat("MotionCard+SpaceTransition.swift")
        #expect(rows.contains(".disabled(spaceTransitionLuaOwned)"))
        #expect(
            rows.contains(
                "varspaceTransitionLuaOwned:Bool{!model.guiManaged}"
            )
        )
        #expect(
            rows.contains(
                "spaceTransitionLuaOwned||model.appWide"
                    + ".spaceTransition!=.slide"
            )
        )
        let card = try flat("MotionCard.swift")
        #expect(
            card.contains(
                "key==.colours(.spaceSlideDuration)"
                    + "&&spaceSlideDurationInert"
            )
        )
    }

    /// The Reveal row sits under Each bar, at rest rather than in
    /// the Style drawer (owner ruling, 2026-10-21).
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
