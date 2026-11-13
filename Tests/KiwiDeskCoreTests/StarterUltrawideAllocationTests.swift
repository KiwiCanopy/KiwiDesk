import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// An ultrawide among several screens (#1662): Scrolling on the
/// ultrawides alone, every other screen of two or more Spaces
/// leads Monocle and ends in its own Floating space; the budget is
/// the ladder's (#3294).
@Suite("Starter allocation beside an ultrawide (#1662)")
struct StarterUltrawideAllocationTests {
    private let superWide = CGSize(width: 5120, height: 1440)
    private let ultrawide = CGSize(width: 3440, height: 1440)
    private let screen27 = CGSize(width: 2560, height: 1440)
    private let portrait = CGSize(width: 1440, height: 2560)
    private let laptop = CGSize(width: 1512, height: 982)

    @Test("below four screens a companion is Monocle · Floating")
    func companions() {
        let wide: [LayoutMode] = [.scrolling, .stack, .floating]
        let pair: [LayoutMode] = [.monocle, .floating]
        #expect(
            StarterAllocation.modes(sizes: [ultrawide, screen27])
                == [wide, pair]
        )
        #expect(
            StarterAllocation.modes(sizes: [ultrawide, portrait])
                == [wide, pair]
        )
        #expect(
            StarterAllocation.modes(sizes: [laptop, ultrawide])
                == [pair, wide]
        )
    }

    /// A screen left one Space takes its single-Space order, and
    /// the ultrawide's Stack keeps its own tuning.
    @Test("a one-Space companion takes its single-Space order")
    func ruledPerScreen() {
        let three = [laptop, portrait, superWide]
        let modes = StarterAllocation.modes(sizes: three)
        #expect(modes[0] == [.monocle])
        #expect(modes[1] == [.grid])
        #expect(modes[2] == [.scrolling, .stack, .floating])
        let settings = StarterSetup.settings(sizes: three)
        #expect(settings.stack.masterCount == 3)
        #expect(settings.stack.stackPosition == .right)
        // A narrow ultrawide no wider than the widescreen beside it
        // (2560 x 1080) still takes Stack when it draws three.
        let narrow = CGSize(width: 2560, height: 1080)
        #expect(
            StarterAllocation.modes(sizes: [narrow, screen27])
                == [
                    [.scrolling, .stack, .floating],
                    [.monocle, .floating],
                ]
        )
        // Two ultrawides never share one Stack's tuning: the
        // second, left one Space, draws past the first's Stack.
        let twins = StarterAllocation.modes(
            sizes: [superWide, ultrawide, ultrawide, laptop]
        )
        #expect(twins[1] == [.stack])
        #expect(twins[2] == [.track])
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
                    block.count == 1
                        || block.first == (wide ? .scrolling : .monocle),
                    "\(sizes[index]): \(block)"
                )
                if !wide {
                    #expect(!block.contains(.scrolling), "\(block)")
                }
            }
        }
    }

    @Test("a lone ultrawide is not a companion setup")
    func budget() {
        #expect(!StarterAllocation.hasUltrawideCompanion([ultrawide]))
        #expect(
            StarterAllocation.modes(sizes: [ultrawide])[0].count
                == StarterAllocation.budget(screenCount: 1)
        )
    }

    @Test("a companion Grid is tuned for the screen it sits on")
    func companionGridShape() {
        // The portrait holds one Space; the laptop beside it,
        // wider, took Monocle, so the portrait draws Grid.
        let tall = StarterSetup.settings(
            sizes: [ultrawide, portrait, laptop]
        )
        #expect(tall.grid.columns == 1)
        #expect(tall.grid.rows == 3)
        #expect(tall.grid.splitDirection == .vertical)
        let pair = StarterSetup.settings(sizes: [laptop, ultrawide])
        // Scrolling lives on the ultrawide, so it is tuned there
        // and needs no per-space override.
        #expect(pair.scrolling.anchor == .center)
        #expect(pair.scrolling.override.isEmpty)
    }
}
