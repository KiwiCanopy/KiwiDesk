import CoreGraphics
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The stories a read-only layout thumbnail plays (#1750), and the
/// schematic inputs they drive. `@MainActor` because the Scrolling
/// and Floating quantities are `View` properties; the spend is a
/// handful of arithmetic reads.
@Suite("Layout stories (#1750)")
@MainActor
struct LayoutStoryTests {
    /// Every story ends on the frame the other surfaces draw: the
    /// resting count and no motion. That end is all Reduce Motion
    /// ever shows, so it must be today's still thumbnail.
    @Test(
        "every story rests on the still frame",
        arguments: LayoutMode.allCases
    )
    func restsOnTheStillFrame(mode: LayoutMode) {
        for windows in [3, 4, 5] {
            let story = LayoutStory.of(mode, resting: windows)
            #expect(story.rest.windows == windows)
            #expect(story.rest.motion == .rest)
            #expect(story.plays, "\(mode) at \(windows)")
        }
    }

    /// A tiling layout's beat is a window ARRIVING, which the
    /// engine places; the others move without adding one.
    @Test(
        "tiling layouts gain one window; the rest move",
        arguments: LayoutMode.allCases
    )
    func beats(mode: LayoutMode) {
        let story = LayoutStory.of(mode, resting: 4)
        switch mode {
        case .bsp, .stack, .grid, .track:
            #expect(story.start.windows == 3)
            #expect(story.start.motion == .rest)
        case .scrolling:
            #expect(story.start.windows == 4)
            #expect(story.start.motion.focus != 0)
        case .monocle:
            #expect(story.start.windows == 4)
            // A whole number of half-turns is the resting card.
            let turn = story.start.motion.turn
            #expect(turn != 0 && turn == turn.rounded())
        case .floating:
            #expect(story.start.windows == 4)
            #expect(story.start.motion.drag < 1)
        }
    }

    /// A count already at its layout's floor has no window to
    /// add, so it stays still rather than drawing below the band.
    @Test("a floor count stays still")
    func floorStaysStill() {
        for mode in [LayoutMode.bsp, .grid, .track] {
            let floor = LayoutSchematic.windowCountRange(for: mode)
                .lowerBound
            #expect(!LayoutStory.of(mode, resting: floor).plays)
        }
    }

    /// The tour's rows rest on the counts the owner ruled: BSP and
    /// Grid take a fourth window, the others a third.
    @Test("the tour's resting counts")
    func tourCounts() {
        let counts = Dictionary(
            uniqueKeysWithValues: LayoutMode.allCases.map {
                ($0, OnboardingSpaceRow.restingWindows($0))
            }
        )
        #expect(counts[.bsp] == 4)
        #expect(counts[.grid] == 4)
        for mode in [LayoutMode.stack, .track, .scrolling] {
            #expect(counts[mode] == 3)
        }
    }

    private func scrolling(step: Int) -> ScrollingSchematic {
        ScrollingSchematic(
            orientation: .horizontal,
            anchor: .center,
            slotSize: .fraction(clamping: 0.5),
            placement: .afterFocused,
            windows: 3,
            scale: .tile,
            focusStep: step
        )
    }

    /// A step moves focus to a real window, never onto the `+`,
    /// and the engine pans the row so that window sits where the
    /// anchor puts it — the resting focus moves off its spot.
    @Test("a focus step skips the incoming window and pans")
    func scrollingStep() {
        let rest = scrolling(step: 0)
        let stepped = scrolling(step: 1)
        #expect(rest.focusIndex == 0)
        let focus = stepped.focusIndex
        #expect(focus != 0)
        #expect(focus != stepped.row.incoming)
        let along: CGFloat = 128
        let r = rest.metrics(along: along)
        let s = stepped.metrics(along: along)
        #expect(s.focus == focus)
        // Centre anchor: whichever window holds focus sits at
        // the screen's centre, so the row moved under it.
        #expect(abs(stepped.center(focus, s) - along / 2) < 0.5)
        #expect(abs(rest.center(0, r) - along / 2) < 0.5)
        #expect(abs(stepped.center(0, s) - rest.center(0, r)) > 1)
    }

    /// The drag moves the front window alone, from its pick-up to
    /// where it rests; the others never move.
    @Test("the floating drag moves the front window only")
    func floatingDrag() {
        let size = CGSize(width: 128, height: 84)
        let picked = FloatingSchematic(windows: 3, drag: 0)
        let left = FloatingSchematic(windows: 3, drag: 1)
        for level in 0..<2 {
            #expect(
                picked.frame(level, in: size)
                    == left.frame(level, in: size)
            )
        }
        let start = picked.frame(2, in: size)
        let end = left.frame(2, in: size)
        #expect(start.origin != end.origin)
        #expect(start.size == end.size)
        #expect(
            abs(start.minX - FloatingSchematic.pickUp.x * size.width)
                < 0.01
        )
    }
}
