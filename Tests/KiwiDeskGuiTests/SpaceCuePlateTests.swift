import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// The Space cue's GUI half (#2143): the one spoken sentence, a
/// cue that never steps, and the master that no longer reaches the
/// Space switch picker (owner, 2026-10-11).
@Suite("Space cue plate (#2143)")
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

    /// The window animations' master counts no Space switch style,
    /// so turning it off leaves the picker's choice standing.
    @Test("the master ignores the Space switch style")
    func masterIgnoresTheStyle() {
        var a = AnimationSettings()
        a.onWindowResize = false
        a.onWindowSwap = false
        a.onRelayout = false
        for style in SpaceChangeStyle.allCases {
            a.spaceChange = style
            #expect(!a.anyEnabled)
        }
    }

    /// The master's setter, the half the getter cannot show: off
    /// and back on leaves the picker's choice standing.
    @Test("the master's switch leaves the style alone")
    func masterSetterLeavesTheStyle() {
        let model = makeTestModel()
        model.config.settings.animations.spaceChange = .slide
        let master = MotionCard(model: model).animationsMasterBinding
        master.wrappedValue = false
        #expect(model.config.settings.animations.spaceChange == .slide)
        master.wrappedValue = true
        #expect(model.config.settings.animations.spaceChange == .slide)
    }

    /// The picker stays live under Reduce Motion; the duration it
    /// gates greys with the card (owner, 2026-10-11).
    @Test("only the picker escapes Reduce Motion's grey")
    func pickerIsExempt() {
        let picker = SettingKey.colours(.animationsSpaceChange)
        let duration = SettingKey.colours(.animationsSpaceChangeDurationMS)
        #expect(picker.placement.exemptFromContainerGate)
        #expect(!duration.placement.exemptFromContainerGate)
    }
}
