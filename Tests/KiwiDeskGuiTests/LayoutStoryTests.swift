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

    /// A lone window has nothing to arrive beside, so it stays
    /// still; from two windows a story starts on one.
    @Test("a lone window stays still; two windows play")
    func loneStaysStill() {
        for mode in [LayoutMode.bsp, .stack, .grid, .track] {
            #expect(!LayoutStory.of(mode, resting: 1).plays)
            #expect(LayoutStory.of(mode, resting: 2).start.windows == 1)
        }
    }

    /// Every host rests on the counts the owner ruled: BSP and
    /// Grid take a fourth window, every other layout a third.
    @Test("the ruled resting counts", arguments: LayoutMode.allCases)
    func restingCounts(mode: LayoutMode) {
        let expected = [LayoutMode.bsp, .grid].contains(mode) ? 4 : 3
        #expect(LayoutStory.ruledWindows(for: mode) == expected)
        #expect(
            LayoutStory.restingWindows(
                for: mode,
                settings: TilingSettings()
            ) == expected
        )
    }

    /// The player takes that count itself, so two hosts cannot
    /// tell one layout's story at two different counts.
    @Test(
        "the player rests on the ruled count",
        arguments: LayoutMode.allCases
    )
    func playerTakesTheCount(mode: LayoutMode) {
        let player = LayoutStoryThumbnail(
            mode: mode,
            settings: TilingSettings(),
            scale: .tile
        )
        #expect(
            player.story.rest.windows
                == LayoutStory.restingWindows(
                    for: mode,
                    settings: TilingSettings()
                )
        )
    }

    private func scrolling(
        step: Int,
        anchor: ScrollingParams.Anchor = .center
    ) -> ScrollingSchematic {
        ScrollingSchematic(
            orientation: .horizontal,
            anchor: anchor,
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

    /// Under a fixed anchor the stepped focus rests exactly
    /// where the resting one sat: the pan is the row moving
    /// under a still focus, so window positions must be counted
    /// from the focus, not from the resting slot. (The focused
    /// position handed to the engine cancels out of every
    /// anchor's rest, so it is not what this watches.)
    @Test(
        "a fixed anchor rests the stepped focus where rest did",
        arguments: [ScrollingParams.Anchor.start, .end]
    )
    func steppedFocusTakesTheAnchor(anchor: ScrollingParams.Anchor) {
        let rest = scrolling(step: 0, anchor: anchor)
        let stepped = scrolling(step: 1, anchor: anchor)
        let along: CGFloat = 128
        let r = rest.metrics(along: along)
        let s = stepped.metrics(along: along)
        #expect(stepped.focusIndex != 0)
        #expect(
            abs(stepped.center(stepped.focusIndex, s) - rest.center(0, r))
                < 0.5
        )
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
        #expect(
            abs(start.minY - FloatingSchematic.pickUp.y * size.height)
                < 0.01
        )
    }
}
