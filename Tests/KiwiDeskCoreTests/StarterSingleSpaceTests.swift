import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The #3294 ladder: from four screens the widest holds its lead
/// and Floating, every other screen one Space, and a one-Space
/// screen takes its shape's single-Space order without repeats.
@Suite("Starter allocation: one-Space screens (#3294)")
struct StarterSingleSpaceTests {
    private let laptop = CGSize(width: 1728, height: 1117)
    private let screen27 = CGSize(width: 2560, height: 1440)
    private let bigDesk = CGSize(width: 2880, height: 1620)
    private let ultrawide = CGSize(width: 3440, height: 1440)
    private let superWide = CGSize(width: 5120, height: 1440)
    private let portrait = CGSize(width: 1440, height: 2560)

    @Test("each shape's single-Space order is the ruled one")
    func orders() {
        // The shape's own list, the laptop's reversed.
        for shape in ScreenClass.allCases {
            let own = shape.layouts
            #expect(
                StarterAllocation.singleSpaceOrder(for: shape)
                    == (shape == .laptop ? own.reversed() : own)
            )
        }
        let order = StarterAllocation.singleSpaceOrder(for:)
        #expect(order(.laptop) == [.monocle, .scrolling])
        #expect(order(.desktop) == [.grid, .stack, .bsp, .scrolling])
        #expect(order(.ultrawide) == [.stack, .track, .grid])
        #expect(order(.superUltrawide) == [.stack, .track, .grid])
        #expect(order(.pivoted) == [.stack, .grid, .monocle])
    }

    @Test("the first layout placed nowhere wins, else the least")
    func pick() {
        let pick = StarterAllocation.singleSpaceLayout(for:placed:)
        #expect(pick(.desktop, []) == .grid)
        #expect(pick(.desktop, [.grid, .scrolling]) == .stack)
        #expect(pick(.pivoted, [.stack, .grid]) == .monocle)
        // Every entry placed: the least placed, earlier on a tie.
        let all: [LayoutMode] = [.grid, .stack, .bsp, .scrolling]
        #expect(pick(.desktop, all + [.grid]) == .stack)
        #expect(pick(.laptop, [.monocle, .scrolling]) == .monocle)
    }

    @Test("from four screens the widest alone holds two Spaces")
    func wideDesk() {
        let sizes = [laptop, screen27, bigDesk, portrait]
        let modes = StarterAllocation.modes(sizes: sizes)
        #expect(modes[2] == [.scrolling, .floating])
        #expect(modes[1] == [.grid])
        #expect(modes[3] == [.stack])
        // A laptop on a four-screen desk opens in Monocle.
        #expect(modes[0] == [.monocle])
        #expect(
            modes.joined().count
                == StarterAllocation.budget(screenCount: 4)
        )
    }

    @Test("a big desk keeps its variety")
    func variety() {
        let modes = StarterAllocation.modes(
            sizes: [bigDesk, screen27, screen27, screen27]
        )
        #expect(
            modes == [[.scrolling, .floating], [.grid], [.stack], [.bsp]]
        )
    }

    /// From four screens the one Floating on the widest overrides
    /// #1662's Floating on every screen beside an ultrawide.
    @Test("beside an ultrawide, four screens hold one Floating")
    func wideDeskWithUltrawide() {
        let sizes = [laptop, superWide, ultrawide, screen27]
        let modes = StarterAllocation.modes(sizes: sizes)
        #expect(StarterAllocation.hasUltrawideCompanion(sizes))
        #expect(modes[1] == [.scrolling, .floating])
        // The second ultrawide takes Stack, the 27" Grid.
        #expect(modes[2] == [.stack])
        #expect(modes[3] == [.grid])
        #expect(modes[0] == [.monocle])
        #expect(modes.joined().count(where: { $0 == .floating }) == 1)
    }

    @Test("every count from four to the cap fills its budget")
    func wideDeskTotals() {
        for count in 4...11 {
            let sizes =
                [bigDesk]
                + Array(
                    repeating: screen27,
                    count: count - 1
                )
            let modes = StarterAllocation.modes(sizes: sizes)
            let budget = StarterAllocation.budget(screenCount: count)
            #expect(modes.joined().count == budget, "\(count)")
            #expect(modes.dropFirst().allSatisfy { $0.count == 1 })
            #expect(
                modes[0].contains(.floating) == (budget > count),
                "\(count): \(modes[0])"
            )
        }
    }
}
