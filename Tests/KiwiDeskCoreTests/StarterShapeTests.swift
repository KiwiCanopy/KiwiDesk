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
        let wide = StarterTuning.settings(
            mainShape: .superUltrawide,
            hosts: [:]
        )
        #expect(wide.scrolling.anchor == .center)
        #expect(!wide.scrolling.fillWhenAlone)
        #expect(wide.stack.masterCount == 3)
        #expect(wide.stack.stackPosition == .right)
        let ultra = StarterTuning.settings(
            mainShape: .ultrawide,
            hosts: [:]
        )
        #expect(ultra.scrolling.anchor == .center)
        #expect(!ultra.scrolling.fillWhenAlone)
        #expect(ultra.stack.masterCount == 2)
        // A 16:9 keeps the defaults the ruling left alone.
        let desk = StarterTuning.settings(
            mainShape: .desktop,
            hosts: [:]
        )
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
        // A portrait main beside a WIDER laptop (1728 against
        // 1440 pt) is the narrowest screen and leads Monocle, then
        // draws Stack — which is tuned for portrait.
        let tall = [portrait, laptop]
        #expect(StarterSetup.hosts(tall)[.stack] == .pivoted)
        #expect(
            StarterSetup.settings(sizes: tall).stack.stackPosition
                == .bottom
        )
        // Host differs from main: a 32:9 secondary draws the Stack
        // beside a 21:9 main, and gets three mains, not two.
        #expect(
            StarterSetup.settings(sizes: [ultrawide, superWide])
                .stack.masterCount == 3
        )
        // Stack lands twice across four screens — three 27"s draw
        // Grid, Stack and BSP, and the portrait's second space is
        // a forced repeat of Stack. The FIRST slot (a 27") tunes
        // it, never the later portrait.
        let four = StarterSetup.settings(
            sizes: [screen27, screen27, screen27, portrait]
        )
        #expect(four.stack.stackPosition == .right)
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
        // The main's Scrolling carries no override.
        #expect(StarterSetup.scrollingOverrides([screen27]).isEmpty)
    }

    /// A portrait main narrower than its landscape secondary leads
    /// Monocle, so Scrolling first lands on the landscape screen
    /// and is tuned for it — never the portrait's vertical.
    @Test("Scrolling is tuned by the screen that leads it")
    func scrollingFollowsItsHost() {
        for secondary in [screen27, ultrawide] {
            let sizes = [portrait, secondary]
            #expect(
                StarterSetup.hosts(sizes)[.scrolling]
                    == ScreenClass.of(secondary)
            )
            let settings = StarterSetup.settings(sizes: sizes)
            #expect(settings.scrolling.orientation == .horizontal)
            #expect(settings.scrolling.override.isEmpty)
        }
        #expect(
            StarterSetup.settings(sizes: [portrait, ultrawide])
                .scrolling.anchor == .center
        )
        // A laptop main beside an ultrawide leads Monocle and never
        // scrolls; the ultrawide tunes Scrolling.
        let mixed = [CGSize(width: 1512, height: 982), ultrawide]
        #expect(StarterSetup.scrollingHost(mixed) == .ultrawide)
        let tuned = StarterSetup.settings(sizes: mixed).scrolling
        #expect(tuned.anchor == .center)
        #expect(!tuned.fillWhenAlone)
    }

    /// The starter's per-space overrides are Scrolling DIRECTION
    /// only; any other override in any setup is a new ruling.
    @Test("the starter overrides nothing but scroll direction")
    func onlyDirectionOverrides() {
        let shapes = [laptop, screen27, ultrawide, superWide, portrait]
        var setups = shapes.map { [$0] }
        for main in shapes {
            for other in shapes { setups.append([main, other]) }
        }
        setups.append([screen27, portrait, CGSize(width: 1280, height: 800)])
        // A portrait MAIN that leads Scrolling (the 1280 pt laptop is
        // narrower, so it leads Monocle): vertical is profile-wide,
        // and the laptop's own Scrolling, if any, turns back.
        setups.append([portrait, CGSize(width: 1280, height: 800)])
        for sizes in setups {
            let settings = StarterSetup.settings(sizes: sizes)
            // Every Scrolling space scrolls the way its screen faces.
            for slot in StarterSetup.slots(sizes)
            where slot.mode == .scrolling {
                let own = StarterTuning.scrollingOrientation(
                    for: ScreenClass.of(sizes[slot.screen])
                )
                let drawn =
                    settings.scrolling.override[SpaceID(slot.number)]?
                    .orientation ?? settings.scrolling.orientation
                #expect(drawn == own, "\(slot) in \(sizes)")
            }
            #expect(settings.bsp.override.isEmpty, "\(sizes)")
            #expect(settings.stack.override.isEmpty, "\(sizes)")
            #expect(settings.grid.override.isEmpty, "\(sizes)")
            #expect(settings.monocle.override.isEmpty, "\(sizes)")
            for (_, override) in settings.scrolling.override {
                var direction = ScrollingOverride()
                direction.orientation = override.orientation
                #expect(override == direction, "\(sizes)")
            }
            // On one or two screens the allocator places each tuned
            // layout once; three or more may force a repeat, which
            // takes the first screen's tuning (`tuningFollowsHost`).
            let slots = StarterSetup.slots(sizes)
            for mode in [LayoutMode.stack, .grid, .track] {
                #expect(
                    slots.filter { $0.mode == mode }.count <= 1,
                    "\(mode) twice in \(sizes)"
                )
            }
        }
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
