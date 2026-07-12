import CoreGraphics
import Testing

@testable import KiwiDeskCore

private func ids(_ n: Int) -> [WindowID] {
    (1...n).map { WindowID(UInt32($0)) }
}

private func makeContext(
    bounds: CGRect,
    breaks: Set<WindowID> = [],
    tune: (inout LayoutContext) -> Void = { _ in }
) -> LayoutContext {
    var context = LayoutContext(
        bounds: bounds,
        gaps: .uniform(10),
        trackBreaks: breaks,
        trackWeights: [:]
    )
    tune(&context)
    return context
}

/// Track `overflow_style` geometry (#188). The knob shapes how an
/// over-capacity *track* renders its windows: `cascade_all` (the
/// track default) piles every window from the top; the
/// `cascade_overflow` prefix-then-pile behavior is pinned in
/// `TrackLayoutTests`.
@Suite("Track overflow style (#188)")
struct TrackOverflowStyleTests {
    let layout = TrackLayout()

    @Test("cascade_all piles every window from the top")
    func cascadeAllPilesAll() {
        // One track, more windows than fit at min size. Under
        // cascade_all none stays tiled at a proportional share:
        // every window keeps the full track height and steps
        // down by the title-bar offset.
        let w = ids(6)
        let bounds = CGRect(x: 0, y: 0, width: 1200, height: 1600)
        let frames = layout.calculateGeometry(
            for: w,
            in: makeContext(bounds: bounds, breaks: [w[0]]) {
                $0.minWindowSize = 300
                $0.track.overflowStyle = .cascadeAll
            }
        )
        // No proportional tiling: every window is full-height.
        let heights = Set(w.map { frames[$0]!.height })
        #expect(heights.count == 1)
        #expect(heights.first! > 300.5)
        // Stepped down by the shared 40 pt title-bar offset at a
        // single x — a top-anchored cascade, not a tiled column.
        #expect(Set(w.map { frames[$0]!.minX }).count == 1)
        let ys = w.map { frames[$0]!.minY }.sorted()
        #expect(abs((ys[1] - ys[0]) - 40) < 0.001)
    }

    @Test("cascade_all differs from cascade_overflow")
    func stylesDiffer() {
        let w = ids(8)
        let bounds = CGRect(x: 0, y: 0, width: 1200, height: 1600)
        func heights(
            _ style: StackParams.OverflowStyle
        ) -> [CGFloat] {
            let frames = layout.calculateGeometry(
                for: w,
                in: makeContext(bounds: bounds, breaks: [w[0]]) {
                    $0.minWindowSize = 300
                    $0.track.overflowStyle = style
                }
            )
            return w.map { frames[$0]!.height }
        }
        // cascade_overflow keeps a tiled prefix (some windows
        // taller than the pile's min height); cascade_all makes
        // them uniform.
        #expect(Set(heights(.cascadeOverflow)).count > 1)
        #expect(Set(heights(.cascadeAll)).count == 1)
    }
}
