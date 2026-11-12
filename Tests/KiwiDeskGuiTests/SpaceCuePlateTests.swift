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

    /// The picker and the slide's pace are a card of their own
    /// (#3218), apart from the window master, outside Reduce
    /// Motion's grey, and grey where init.lua owns the config
    /// (#2524) — never in the bars' Show group, where #2228 had its
    /// switch.
    @Test("the picker and its pace are the Space switch card")
    func pickerIsTheSpaceSwitchCard() {
        #expect(
            ColorsRowOrder.spaceSwitch == [
                .colours(.spaceTransition),
                .colours(.spaceScrollTransition),
                .colours(.spaceSlideDuration),
            ]
        )
        #expect(ColorsRowOrder.motionAtRest == [.colours(.animationsMaster)])
        #expect(SettingsContainer.spaceSwitch.gate == nil)
        for key in [
            SettingKey.colours(.spaceTransition),
            .colours(.spaceScrollTransition),
            .colours(.spaceSlideDuration),
        ] {
            let placement = key.placement
            #expect(placement.area == .coloursAndMotion)
            #expect(placement.container == .spaceSwitch)
            #expect(placement.gate == .runtime(.luaOwnsConfig))
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
        let rows = try flat("SpaceSwitchCard+Rows.swift")
        // On the picker's DropdownRow, never a caption beside it.
        #expect(
            rows.contains(
                ".neutralMenuLabel()}.disabled(spaceTransitionLuaOwned)"
            )
        )
        #expect(
            rows.contains(
                "varspaceTransitionLuaOwned:Bool{!model.guiManaged}"
            )
        )
        #expect(
            rows.contains(
                "spaceTransitionLuaOwned||![model.appWide.spaceTransition,"
                    + "model.appWide.spaceScrollTransition,]"
                    + ".contains{$0.drawn(reduceMotion:reduceMotion)==.slide}"
            )
        )
        // The scroll step's picker greys the same way and writes its
        // own member; its caption speaks only where the picks differ
        // (#2971), a surfacing branch nothing else can see.
        #expect(
            rows.components(
                separatedBy: ".neutralMenuLabel()}"
                    + ".disabled(spaceTransitionLuaOwned)"
            ).count == 3
        )
        #expect(rows.contains("$0.spaceScrollTransition=pick"))
        #expect(
            rows.contains(
                "ifstyle!=model.appWide.spaceTransition{"
                    + "Text(spaceTransitionCaption(style))"
            )
        )
        let card = try flat("SpaceSwitchCard.swift")
        // The predicate is applied to the card's rows, not only
        // declared.
        #expect(
            card.contains(
                "ForEach(ColorsRowOrder.spaceSwitch,id:\\.id){keyin"
                    + "row(for:key).modifier(GreyOut(active:greyed(key)))"
            )
        )
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
