import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// An ultrawide among several screens (#1662): Scrolling on the
/// ultrawides alone, every other screen leads Monocle, three spaces
/// a screen, and each screen ends in its own Floating space.
@Suite("Starter allocation beside an ultrawide (#1662)")
struct StarterUltrawideAllocationTests {
    private let superWide = CGSize(width: 5120, height: 1440)
    private let ultrawide = CGSize(width: 3440, height: 1440)
    private let screen27 = CGSize(width: 2560, height: 1440)
    private let portrait = CGSize(width: 1440, height: 2560)
    private let laptop = CGSize(width: 1512, height: 982)

    @Test("each companion screen gets its ruled three")
    func companions() {
        let wide: [LayoutMode] = [.scrolling, .stack, .floating]
        #expect(
            StarterAllocation.modes(sizes: [ultrawide, screen27])
                == [wide, [.monocle, .bsp, .floating]]
        )
        #expect(
            StarterAllocation.modes(sizes: [ultrawide, portrait])
                == [wide, [.monocle, .grid, .floating]]
        )
        #expect(
            StarterAllocation.modes(sizes: [laptop, ultrawide])
                == [[.monocle, .grid, .floating], wide]
        )
    }

    /// The table is PER SCREEN: a companion drawn before the
    /// ultrawide, or beside a twin, still gets its ruled layout,
    /// and the ultrawide's Stack keeps its own tuning.
    @Test("each screen gets its ruled layout whatever the order")
    func ruledPerScreen() {
        let twins = StarterAllocation.modes(
            sizes: [screen27, screen27, ultrawide]
        )
        #expect(twins[0] == [.monocle, .bsp, .floating])
        #expect(twins[1] == [.monocle, .bsp, .floating])
        let three = [laptop, portrait, superWide]
        let modes = StarterAllocation.modes(sizes: three)
        #expect(modes[0] == [.monocle, .grid, .floating])
        #expect(modes[1] == [.monocle, .grid, .floating])
        #expect(modes[2] == [.scrolling, .stack, .floating])
        let settings = StarterSetup.settings(sizes: three)
        #expect(settings.stack.masterCount == 3)
        #expect(settings.stack.stackPosition == .right)
        // A narrow ultrawide no wider than the widescreen beside it
        // (2560 x 1080) still takes Stack; the widescreen BSP.
        let narrow = CGSize(width: 2560, height: 1080)
        #expect(
            StarterAllocation.modes(sizes: [screen27, narrow])
                == [
                    [.monocle, .bsp, .floating],
                    [.scrolling, .stack, .floating],
                ]
        )
        // Two ultrawides never share one Stack's tuning.
        #expect(
            StarterAllocation.modes(sizes: [superWide, ultrawide])
                == [
                    [.scrolling, .stack, .floating],
                    [.scrolling, .track, .floating],
                ]
        )
    }

    /// Equal widths, different classes: the host is the allocator's
    /// own tie-break, never a dictionary's order.
    @Test("an equal-width tie picks the Scrolling host stably")
    func scrollingHostTieBreak() {
        let sizes = [
            CGSize(width: 1440, height: 2560),
            CGSize(width: 1440, height: 900),
            CGSize(width: 1024, height: 768),
        ]
        #expect(StarterSetup.scrollingHost(sizes) == .pivoted)
    }

    @Test("Scrolling stays on the ultrawides, others lead Monocle")
    func scrollingOnlyOnUltrawides() {
        let setups: [[CGSize]] = [
            [screen27, ultrawide],
            [superWide, ultrawide],
            [laptop, portrait, superWide],
            [screen27, screen27, ultrawide, portrait],
        ]
        for sizes in setups {
            let modes = StarterAllocation.modes(sizes: sizes)
            for (index, block) in modes.enumerated() {
                let wide = ScreenClass.of(sizes[index]).isUltrawide
                #expect(
                    block.first == (wide ? .scrolling : .monocle),
                    "\(sizes[index]): \(block)"
                )
                if !wide {
                    #expect(!block.contains(.scrolling), "\(block)")
                }
            }
        }
    }

    @Test("three spaces a screen, capped at the digit keys")
    func budget() {
        #expect(StarterAllocation.ultrawideBudget(screenCount: 2) == 6)
        #expect(StarterAllocation.ultrawideBudget(screenCount: 3) == 9)
        #expect(
            StarterAllocation.ultrawideBudget(screenCount: 4)
                == StarterAllocation.softCap
        )
        // One screen keeps the ladder: a lone ultrawide is not a
        // companion setup.
        #expect(!StarterAllocation.hasUltrawideCompanion([ultrawide]))
        #expect(
            StarterAllocation.modes(sizes: [ultrawide])[0].count
                == StarterAllocation.budget(screenCount: 1)
        )
    }

    @Test("a companion Grid is tuned for the screen it sits on")
    func companionGridShape() {
        let tall = StarterSetup.settings(sizes: [ultrawide, portrait])
        #expect(tall.grid.columns == 1)
        #expect(tall.grid.rows == 3)
        #expect(tall.grid.splitDirection == .vertical)
        let pair = StarterSetup.settings(sizes: [laptop, ultrawide])
        #expect(pair.grid.columns == 2)
        #expect(pair.grid.rows == 1)
        // Scrolling lives on the ultrawide, so it is tuned there
        // and needs no per-space override.
        #expect(pair.scrolling.anchor == .center)
        #expect(pair.scrolling.override.isEmpty)
    }
}
