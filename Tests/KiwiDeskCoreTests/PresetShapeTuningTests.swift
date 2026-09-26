import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A preset lays its own leaves over the screen's shape tuning
/// (#1663): what it declares wins, what it does not follows the
/// screen each layout sits on in that preset's plan.
@Suite("Presets build on the screen's shape tuning (#1663)")
struct PresetShapeTuningTests {
    private let laptop = CGSize(width: 1728, height: 1117)
    private let screen27 = CGSize(width: 2560, height: 1440)
    private let portrait = CGSize(width: 1440, height: 2560)
    private let ultrawide = CGSize(width: 3440, height: 1440)
    private let superWide = CGSize(width: 5120, height: 1440)

    private func preset(_ name: String) throws -> StandardLayout {
        try #require(
            StandardProfiles.workflows.first { $0.name == name }
        )
    }

    private func display(_ size: CGSize) -> Display {
        Display(
            id: DisplayID(1),
            name: "S",
            frame: CGRect(origin: .zero, size: size)
        )
    }

    @Test("Minimalist scrolls vertically on a portrait screen")
    func minimalistOnPortrait() throws {
        let minimalist = try preset("Minimalist")
        let settings = minimalist.settings(sizes: [portrait])
        #expect(settings.scrolling.orientation == .vertical)
        #expect(
            minimalist.settings(sizes: [screen27])
                .scrolling.orientation == .horizontal
        )
    }

    @Test("a preset's Stack takes an ultrawide's main count")
    func stackOnUltrawides() throws {
        let focus = try preset("Focus Stack")
        #expect(focus.settings(sizes: [ultrawide]).stack.masterCount == 2)
        #expect(focus.settings(sizes: [superWide]).stack.masterCount == 3)
        #expect(
            focus.settings(sizes: [screen27]).stack.masterCount
                == TilingSettings().stack.masterCount
        )
    }

    /// Minimalist declares gap 20 and a centred anchor; a laptop
    /// tunes gaps to 6 and a 27" leaves the anchor at `follow`.
    @Test("a declared leaf wins over the shape tuning")
    func declaredLeafWins() throws {
        let minimalist = try preset("Minimalist")
        let onLaptop = minimalist.settings(sizes: [laptop])
        #expect(onLaptop.gapsGlobal == .uniform(20))
        #expect(
            minimalist.settings(sizes: [screen27]).scrolling.anchor
                == .center
        )
        // An undeclared gap is the screen's.
        let developer = try preset("Developer")
        #expect(
            developer.settings(sizes: [laptop]).gapsGlobal
                == StarterSetup.settings(sizes: [laptop]).gapsGlobal
        )
    }

    /// The host is the screen the layout's FIRST space sits on in
    /// this plan — here a Stack living only on the second screen.
    @Test("each layout is tuned for its own screen in the plan")
    func hostIsThePlansScreen() {
        let layout = StandardLayout(
            name: "T",
            screenCount: 2,
            spaceCount: 2,
            spaceModes: ["1": .grid, "2": .stack],
            spaceScreens: ["2": 1],
            isStandard: false,
            tuning: .preset(PresetTuning())
        )
        let settings = layout.settings(sizes: [laptop, ultrawide])
        #expect(settings.stack.masterCount == 2)
        #expect(settings.grid.columns == 2)
        #expect(settings.grid.rows == 1)
        // Profile-wide leaves stay the main screen's.
        #expect(settings.gapsGlobal == .uniform(6))
    }

    /// An undeclared Space on an ultrawide second screen takes
    /// that screen's Stack, and so hosts Stack there.
    @Test("an undeclared Space's mode is its own screen's")
    func undeclaredModeHostsOnItsScreen() {
        let layout = StandardLayout(
            name: "T",
            screenCount: 2,
            spaceCount: 2,
            spaceModes: ["1": .scrolling],
            spaceScreens: ["2": 1],
            isStandard: false,
            tuning: .preset(PresetTuning())
        )
        let settings = layout.settings(sizes: [laptop, ultrawide])
        #expect(settings.stack.masterCount == 2)
    }

    /// Stack on the laptop main: the starter hosts it on the
    /// ultrawide it allocates it to, the preset on the laptop.
    @Test("a preset's Stack is hosted where the preset puts it")
    func stackHostIsThePlans() {
        let layout = StandardLayout(
            name: "T",
            screenCount: 2,
            spaceCount: 2,
            spaceModes: ["1": .stack, "2": .grid],
            spaceScreens: ["2": 1],
            isStandard: false,
            tuning: .preset(PresetTuning())
        )
        let sizes = [laptop, ultrawide]
        #expect(StarterSetup.hosts(sizes)[.stack] == .ultrawide)
        #expect(
            layout.settings(sizes: sizes).stack.masterCount
                == TilingSettings().stack.masterCount
        )
    }

    /// Scrolling on a laptop main and an ultrawide second: the
    /// starter would tune it for the ultrawide it leads, a preset
    /// for its first space's screen, the laptop (ruling 6).
    @Test("a preset tunes Scrolling for its first space's screen")
    func scrollingHostIsTheFirstSpace() {
        let layout = StandardLayout(
            name: "T",
            screenCount: 2,
            spaceCount: 2,
            spaceModes: ["1": .scrolling, "2": .scrolling],
            spaceScreens: ["2": 1],
            isStandard: false,
            tuning: .preset(PresetTuning())
        )
        let sizes = [laptop, ultrawide]
        #expect(StarterSetup.scrollingHost(sizes) == .ultrawide)
        let scrolling = layout.settings(sizes: sizes).scrolling
        #expect(
            scrolling.slotSize
                == .fraction(clamping: StarterTuning.standardSlot)
        )
        #expect(scrolling.anchor != .center)
    }

    /// Command Center scrolls on space 3 (main) and space 9 (the
    /// third screen): a portrait third screen turns space 9 alone.
    @Test("a Scrolling space on a turned screen takes its direction")
    func perSpaceDirection() throws {
        let center = try preset("Command Center")
        let settings = center.settings(
            sizes: [screen27, screen27, portrait]
        )
        #expect(settings.scrolling.orientation == .horizontal)
        #expect(
            settings.scrolling.override["9"]?.orientation == .vertical
        )
        #expect(settings.scrolling.override["3"] == nil)
    }

    @Test("where the screens are unknown, no shape tuning applies")
    func unknownScreens() throws {
        let minimalist = try preset("Minimalist")
        var expected = StarterTuning.base()
        expected.gapsGlobal = .uniform(20)
        expected.scrolling.anchor = .center
        #expect(minimalist.settings(sizes: nil) == expected)
    }

    @Test("the starter keeps the settings derived for its screens")
    func starterIsResolved() {
        let starter = StarterSetup.standardLayout(sizes: [ultrawide])
        #expect(
            starter.settings(sizes: [laptop])
                == StarterSetup.settings(sizes: [ultrawide])
        )
    }

    /// The apply door and the monitor-change fallback both compose,
    /// so the composition is where the merge must be taken.
    @Test("composing a preset takes the merge for its screens")
    func composeTakesTheMerge() throws {
        let minimalist = try preset("Minimalist")
        let composed = try #require(
            ProfileComposition.compose(
                layout: minimalist,
                displays: [display(portrait)],
                mainID: DisplayID(1)
            )
        )
        #expect(
            composed.settings == minimalist.settings(sizes: [portrait])
        )
        #expect(composed.settings.scrolling.orientation == .vertical)
    }
}
