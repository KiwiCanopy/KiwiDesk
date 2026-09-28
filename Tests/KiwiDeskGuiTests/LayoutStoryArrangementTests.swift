import CoreGraphics
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The engine arrangement a tiling story draws (#1750). Pure
/// arithmetic over `LayoutEngine`; no view is built.
@Suite("Layout story arrangement (#1750)")
struct LayoutStoryArrangementTests {
    static let canvas = CGSize(width: 128, height: 84)
    static let tiling: [LayoutMode] = [.bsp, .stack, .grid, .track]

    /// Settings a story is drawn under: the defaults, the
    /// starter's tunings, and a grid too small for the story,
    /// whose extra windows pile.
    static var variants: [TilingSettings] {
        var small = TilingSettings()
        small.grid.columns = 2
        small.grid.rows = 1
        var rigid = small
        rigid.grid.type = .rigid
        return unpiled + [small, rigid]
    }

    static var unpiled: [TilingSettings] {
        var starter = TilingSettings()
        starter.track.newWindow = .ownTrack
        starter.stack.masterRatio = 0.8
        return [TilingSettings(), starter]
    }

    /// The engine lays a story out at screen size and the frames
    /// are scaled to the thumbnail, so an unpiled arrangement
    /// fills its canvas and stays inside it. (A pile hangs past
    /// the screen edge on a real screen too; the canvas clips it,
    /// `LayoutStoryWiringTests`.)
    @Test("an unpiled story lies inside its canvas", arguments: tiling)
    func framesStayInside(mode: LayoutMode) {
        let bounds = CGRect(origin: .zero, size: Self.canvas)
            .insetBy(dx: -0.5, dy: -0.5)
        for settings in Self.unpiled {
            for count in 1...4 {
                let frames = LayoutStoryArrangement.frames(
                    mode,
                    settings: settings,
                    count: count,
                    in: Self.canvas
                )
                #expect(frames.count == count, "\(mode) \(count)")
                // Fills it too: outer gaps are zero, so the union
                // reaches every edge.
                let union = frames.values.reduce(CGRect.null) {
                    $0.union($1)
                }
                #expect(abs(union.minX) < 0.5 && abs(union.minY) < 0.5)
                #expect(abs(union.maxX - Self.canvas.width) < 0.5)
                #expect(abs(union.maxY - Self.canvas.height) < 0.5)
                for (id, rect) in frames {
                    #expect(
                        bounds.contains(rect),
                        "\(mode) \(count): window \(id.raw) at \(rect)"
                    )
                }
            }
        }
    }

    /// A pile's cascade step is scaled from a 1280-pt screen, so
    /// it moves a piled window a few points on the thumbnail and
    /// the pile reads inside the cell it fills (#1750).
    @Test("a pile cascades by a screen's proportion")
    func pileStepsInProportion() throws {
        let frames = LayoutStoryArrangement.frames(
            .grid,
            settings: Self.variants[2],
            count: 4,
            in: Self.canvas
        )
        let piled = frames.values.filter { $0.minX > 1 }
            .map(\.minY).sorted()
        try #require(piled.count == 3)
        let step = piled[1] - piled[0]
        let scaled =
            OverlapStack.offset * Self.canvas.width
            / LayoutStoryArrangement.screenWidth
        #expect(abs(step - scaled) < 0.5)
        // And the screen is a screen, not the thumbnail: laid out at
        // thumbnail size the step is the whole unscaled offset.
        #expect(step < OverlapStack.offset / 4)
    }

    /// Windows keep their identity as one arrives: the earlier
    /// arrangement is the later one without the newcomer, in the
    /// same order, so the tween moves only the newcomer and the
    /// windows making room — never two windows trading places.
    @Test("an arrival keeps every other window's identity", arguments: tiling)
    func identitiesAreStable(mode: LayoutMode) {
        for settings in Self.variants {
            for count in 2...6 {
                let before = LayoutStoryArrangement.space(
                    mode,
                    settings: settings,
                    count: count - 1
                )
                let after = LayoutStoryArrangement.space(
                    mode,
                    settings: settings,
                    count: count
                )
                let newcomer = WindowID(UInt32(count))
                #expect(
                    after.windows.filter { $0 != newcomer } == before.windows
                )
                #expect(after.focused == newcomer)
            }
        }
    }

    /// The owner's Grid story: a fourth window lands the grid in
    /// 2 × 2 under the defaults.
    @Test("Grid's fourth window lands in two by two")
    func gridLandsInTwoByTwo() {
        let frames = LayoutStoryArrangement.frames(
            .grid,
            settings: TilingSettings(),
            count: 4,
            in: Self.canvas
        )
        let xs = Set(frames.values.map { Int($0.minX.rounded()) })
        let ys = Set(frames.values.map { Int($0.minY.rounded()) })
        #expect(frames.count == 4)
        #expect(xs.count == 2)
        #expect(ys.count == 2)
    }

    /// Each layout's arrival answers to its OWN new-window
    /// placement: a newcomer placed first leads the array, one
    /// placed last ends it.
    @Test(
        "an arrival takes the layout's own placement",
        arguments: [LayoutMode.bsp, .stack, .grid]
    )
    func arrivalTakesThePlacement(mode: LayoutMode) {
        for (placement, index) in [(SpawnPlacement.first, 0), (.last, 3)] {
            var settings = TilingSettings()
            settings.bsp.newWindowPlacement = .afterFocused
            settings.stack.newWindowPlacement = .afterFocused
            settings.grid.newWindowPlacement = .afterFocused
            switch mode {
            case .bsp: settings.bsp.newWindowPlacement = placement
            case .stack: settings.stack.newWindowPlacement = placement
            default: settings.grid.newWindowPlacement = placement
            }
            let space = LayoutStoryArrangement.space(
                mode,
                settings: settings,
                count: 4
            )
            #expect(
                space.windows.firstIndex(of: WindowID(4)) == index,
                "\(mode) \(placement)"
            )
        }
    }

    /// A grid tuned to fit two tells its arrival within two —
    /// one window joining another side by side — rather than a
    /// fourth window landing on a pile; the default grid keeps
    /// the ruled four.
    @Test("a story rests on what the layout fits without a pile")
    func restsWithinWhatFits() {
        #expect(
            LayoutStory.restingWindows(
                for: .grid,
                settings: Self.variants[2]
            ) == 2
        )
        #expect(
            LayoutStory.restingWindows(
                for: .grid,
                settings: TilingSettings()
            ) == 4
        )
        for settings in Self.variants {
            for mode in Self.tiling {
                let rest = LayoutStory.restingWindows(
                    for: mode,
                    settings: settings
                )
                let rects = Array(
                    LayoutStoryArrangement.frames(
                        mode,
                        settings: settings,
                        count: rest,
                        in: Self.canvas
                    ).values
                )
                for i in rects.indices {
                    for j in rects.indices where j > i {
                        #expect(
                            !rects[i].insetBy(dx: 0.5, dy: 0.5)
                                .intersects(rects[j]),
                            "\(mode) rests on a pile at \(rest)"
                        )
                    }
                }
            }
        }
    }

    /// Only the four tiling layouts tell their story by arrival.
    @Test("the arriving layouts are the tiling four")
    func arrivingLayouts() {
        #expect(
            Set(LayoutMode.allCases.filter(LayoutStoryArrangement.arrives))
                == Set(Self.tiling)
        )
    }
}
