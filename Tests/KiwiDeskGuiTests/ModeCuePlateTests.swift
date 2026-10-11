import CoreGraphics
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The layout-cycle plate's GUI half (#2144): the ring's slots,
/// the one spoken sentence, and the plate replacing what it showed.
@Suite("Layout-cycle plate (#2144)")
@MainActor
struct ModeCuePlateTests {
    private let three: [LayoutMode] = [.bsp, .scrolling, .floating]

    /// First entry at 12 o'clock, the rest clockwise in list
    /// order — screen y grows down, so the second sits right.
    @Test("the ring starts at 12 o'clock and runs clockwise")
    func ringOrder() {
        let centre = ModeCueView.centre
        let top = ModeCueView.slot(of: .bsp, in: three)
        let second = ModeCueView.slot(of: .scrolling, in: three)
        let third = ModeCueView.slot(of: .floating, in: three)
        #expect(abs(top.x - centre.x) < 0.01)
        #expect(top.y < centre.y)
        #expect(second.x > centre.x && second.y > centre.y)
        #expect(third.x < centre.x && third.y > centre.y)
    }

    @Test("VoiceOver hears one sentence naming the layout")
    func spokenSentence() {
        LocalizationManager.shared.select("en")
        let cue = ModeCycleCue(
            display: DisplayID(1),
            cycle: three,
            current: .scrolling
        )
        #expect(CuePlateModel.spoken(.mode(cue)) == "Layout: Scrolling")
    }

    @Test("a cue replaces the last one and shows the plate")
    func presentReplaces() {
        let model = CuePlateModel()
        let first = CuePlateModel.Content.mode(
            ModeCycleCue(display: DisplayID(1), cycle: three, current: .bsp)
        )
        let second = CuePlateModel.Content.mode(
            ModeCycleCue(
                display: DisplayID(1),
                cycle: three,
                current: .scrolling
            )
        )
        model.present(first, reduceMotion: true)
        #expect(model.visible)
        #expect(model.content == first)
        model.present(second, reduceMotion: false)
        #expect(model.content == second)
    }
}
