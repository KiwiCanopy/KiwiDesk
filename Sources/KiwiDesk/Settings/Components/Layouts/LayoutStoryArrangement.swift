import CoreGraphics
import KiwiDeskCore

/// A tiling story's windows, asked of the engine (#702, #1750):
/// windows arrive one at a time through the Space's own insert,
/// each taking focus as a new window does, and the layout places
/// them. Identities are stable across counts, so a story from
/// `count - 1` to `count` moves only the newcomer and the windows
/// that make room for it.
enum LayoutStoryArrangement {
    /// Whether `mode` tells its story by a window arriving.
    static func arrives(_ mode: LayoutMode) -> Bool {
        switch mode {
        case .bsp, .stack, .grid, .track: return true
        case .scrolling, .monocle, .floating: return false
        }
    }

    /// The Space after `count` windows arrived under `settings`.
    static func space(
        _ mode: LayoutMode,
        settings: TilingSettings,
        count: Int
    ) -> Space {
        var space = Space(
            id: "story",
            windows: [WindowID(1)],
            focused: WindowID(1)
        )
        space.trackBreaks = [WindowID(1)]
        for raw in stride(from: 2, through: max(1, count), by: 1) {
            let window = WindowID(UInt32(raw))
            switch mode {
            case .track:
                space.insertIntoTrack(
                    window,
                    rule: settings.track.newWindow,
                    position: settings.track.newWindowPosition,
                    isTiled: { _ in true }
                )
            case .bsp:
                space.insert(
                    window,
                    placement: settings.bsp.newWindowPlacement
                )
            case .stack:
                space.insert(
                    window,
                    placement: settings.stack.newWindowPlacement
                )
            case .grid:
                space.insert(
                    window,
                    placement: settings.grid.newWindowPlacement
                )
            case .scrolling, .monocle, .floating:
                space.windows.append(window)
            }
            space.focused = window
        }
        return space
    }

    /// The most windows, up to `ruled`, that `mode` lays out
    /// under `settings` without piling any: a story rests there,
    /// so a layout tuned to fit fewer (a 2 × 1 grid) tells its
    /// arrival within what it fits rather than onto a pile.
    static func fitting(
        _ mode: LayoutMode,
        settings: TilingSettings,
        upTo ruled: Int
    ) -> Int {
        let canvas = CGSize(width: 128, height: 84)
        return stride(from: max(1, ruled), through: 1, by: -1)
            .first { count in
                let rects = Array(
                    frames(mode, settings: settings, count: count, in: canvas)
                        .values
                )
                return !rects.indices.contains { i in
                    rects.indices.contains { j in
                        j > i
                            && rects[i].insetBy(dx: 0.5, dy: 0.5)
                                .intersects(rects[j])
                    }
                }
            } ?? 1
    }

    /// The width the engine lays a story out at: a real screen's,
    /// so fixed-point quantities — a pile's cascade offset, the
    /// gap — keep their proportion when the frames are scaled down
    /// to the thumbnail.
    static let screenWidth: CGFloat = 1280

    /// Each window's frame on a canvas of `size`: laid out by the
    /// engine on a screen of the canvas's shape, then scaled down,
    /// with the canvas's inner gap and no size floor.
    static func frames(
        _ mode: LayoutMode,
        settings: TilingSettings,
        count: Int,
        in size: CGSize
    ) -> [WindowID: CGRect] {
        guard size.width > 0, size.height > 0 else { return [:] }
        let factor = screenWidth / size.width
        let screen = CGSize(
            width: screenWidth,
            height: size.height * factor
        )
        let space = space(mode, settings: settings, count: count)
        let gap = 3 * factor
        let context = LayoutContext(
            bounds: CGRect(origin: .zero, size: screen),
            gaps: Gaps(
                outer: .init(top: 0, bottom: 0, left: 0, right: 0),
                inner: .init(horizontal: gap, vertical: gap)
            ),
            focused: space.focused,
            minWindowSize: 1,
            trackBreaks: space.trackBreaks,
            bsp: settings.bsp,
            stack: settings.stack,
            grid: settings.grid,
            track: settings.track
        )
        return LayoutEngine.calculate(
            mode: mode,
            windows: space.windows,
            context: context
        )
        .mapValues { rect in
            CGRect(
                x: rect.minX / factor,
                y: rect.minY / factor,
                width: rect.width / factor,
                height: rect.height / factor
            )
        }
    }
}
