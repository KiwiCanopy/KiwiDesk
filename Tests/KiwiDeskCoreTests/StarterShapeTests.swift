import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Screen-shaped starter setups (#1662): the super-ultrawide class,
/// tuning by the screen a layout lands on, the one portrait
/// override, and the title a setup is saved under.
@Suite("Screen-shaped starter setups (#1662)")
struct StarterShapeTests {
    private let superWide = CGSize(width: 5120, height: 1440)
    private let ultrawide = CGSize(width: 3440, height: 1440)
    private let screen27 = CGSize(width: 2560, height: 1440)
    private let portrait = CGSize(width: 1440, height: 2560)
    private let laptop = CGSize(width: 1728, height: 1117)

    @Test("32:9 is super ultrawide, 21:9 stays ultrawide")
    func superUltrawideBoundary() {
        #expect(ScreenClass.of(superWide) == .superUltrawide)
        #expect(ScreenClass.of(ultrawide) == .ultrawide)
        let edge = ScreenClass.superUltrawideAspect
        #expect(
            ScreenClass.of(CGSize(width: edge * 1000, height: 1000))
                == .superUltrawide
        )
        #expect(
            ScreenClass.of(
                CGSize(width: edge * 1000 - 1, height: 1000)
            ) == .ultrawide
        )
        // A rotated 32:9 is a portrait screen, not a new class.
        #expect(
            ScreenClass.of(CGSize(width: 1440, height: 5120))
                == .pivoted
        )
    }

    @Test("one ultrawide screen gets Scrolling, Stack, Floating")
    func singleScreenModes() {
        for size in [superWide, ultrawide, portrait] {
            #expect(
                StarterAllocation.modes(sizes: [size])
                    == [[.scrolling, .stack, .floating]],
                "\(ScreenClass.of(size))"
            )
        }
    }

    @Test("the ultrawides centre, keep a lone window, and widen")
    func ultrawideTuning() {
        let wide = StarterTuning.settings(mainShape: .superUltrawide)
        #expect(wide.scrolling.anchor == .center)
        #expect(!wide.scrolling.fillWhenAlone)
        #expect(wide.stack.masterCount == 3)
        #expect(wide.stack.stackPosition == .right)
        let ultra = StarterTuning.settings(mainShape: .ultrawide)
        #expect(ultra.scrolling.anchor == .center)
        #expect(!ultra.scrolling.fillWhenAlone)
        #expect(ultra.stack.masterCount == 2)
        // A 16:9 keeps the defaults the ruling left alone.
        let desk = StarterTuning.settings(mainShape: .desktop)
        #expect(desk.scrolling.anchor == .follow)
        #expect(desk.scrolling.fillWhenAlone)
        #expect(desk.stack.masterCount == 1)
    }

    @Test("a layout is tuned for the screen it lands on")
    func tuningFollowsHost() {
        let sizes = [ultrawide, portrait]
        let hosts = StarterSetup.hosts(sizes)
        // Both lead their lists with Stack; the wider draws first.
        #expect(hosts[.stack] == .ultrawide)
        let settings = StarterSetup.settings(sizes: sizes)
        #expect(settings.stack.masterCount == 2)
        #expect(settings.stack.stackPosition == .right)
        // Reversed roles: a portrait main hosting Stack beside a
        // smaller laptop tunes Stack for portrait.
        let tall = [portrait, laptop]
        #expect(StarterSetup.hosts(tall)[.stack] == .pivoted)
        #expect(
            StarterSetup.settings(sizes: tall).stack.stackPosition
                == .bottom
        )
    }

    @Test("Scrolling on a portrait secondary scrolls vertically")
    func portraitSecondaryOverride() throws {
        // A 1280 pt laptop is narrower than the 1440 pt portrait,
        // so it leads Monocle and the portrait leads Scrolling.
        let small = CGSize(width: 1280, height: 800)
        let sizes = [screen27, portrait, small]
        let overrides = StarterSetup.scrollingOverrides(sizes)
        let portraitScrolling = StarterSetup.slots(sizes)
            .filter { $0.screen == 1 && $0.mode == .scrolling }
        try #require(portraitScrolling.count == 1)
        let space = SpaceID(portraitScrolling[0].number)
        #expect(Set(overrides.keys) == [space])
        #expect(overrides[space]?.orientation == .vertical)
        #expect(
            StarterSetup.settings(sizes: sizes).scrolling
                .override[space]?.orientation == .vertical
        )
        // The main's Scrolling carries no override, and a portrait
        // MAIN needs none: its direction is already profile-wide.
        #expect(StarterSetup.scrollingOverrides([screen27]).isEmpty)
        #expect(
            StarterSetup.scrollingOverrides([portrait, screen27])
                .isEmpty
        )
    }

    @Test("the setup is titled by its main screen, named Starter")
    func titles() {
        let one = StarterSetup.standardLayout(sizes: [superWide])
        #expect(one.name == StarterSetup.name)
        #expect(one.starterTitle?.profileName == "Super Ultrawide")
        let two = StarterSetup.standardLayout(
            sizes: [screen27, laptop]
        )
        #expect(two.starterTitle?.profileName == "Widescreen + 1")
        let names = ScreenClass.allCases.map(StarterTitle.name(of:))
        #expect(Set(names).count == ScreenClass.allCases.count)
        #expect(!names.contains(StarterSetup.name))
        // Every shipped preset carries no title.
        #expect(
            StandardProfiles.workflows.allSatisfy {
                $0.starterTitle == nil
            }
        )
    }
}
