import KiwiDeskCore

/// The one beat a layout's thumbnail plays on a surface that is
/// read rather than compared — the welcome tour and the preset
/// preview (#1750): a start frame, and the rest frame the
/// thumbnail draws everywhere else and under Reduce Motion.
struct LayoutStory: Equatable {
    struct Frame: Equatable {
        var windows: Int
        var motion: SchematicMotion = .rest
    }

    let start: Frame
    let rest: Frame

    /// Whether there is anything to play: a story whose start is
    /// its rest (a single window, with nothing to arrive) stays
    /// still.
    var plays: Bool { start != rest }

    /// The ruled window count a story rests on: BSP's and
    /// Grid's newcomer is the fourth window, the others' the
    /// third (owner ruling, #1750).
    static func ruledWindows(for mode: LayoutMode) -> Int {
        switch mode {
        case .bsp, .grid: return 4
        case .stack, .track, .scrolling, .monocle, .floating:
            return 3
        }
    }

    /// The count a story rests on, on every host: the ruled one,
    /// lowered for a tiling layout to what its settings lay out
    /// without a pile. That frame is all Reduce Motion shows.
    static func restingWindows(
        for mode: LayoutMode,
        settings: TilingSettings
    ) -> Int {
        let ruled = ruledWindows(for: mode)
        guard LayoutStoryArrangement.arrives(mode) else { return ruled }
        return LayoutStoryArrangement.fitting(
            mode,
            settings: settings,
            upTo: ruled
        )
    }

    /// `mode`'s story ending on `windows`, the count the surface
    /// draws at rest. Tiling layouts gain a window, which the
    /// engine places; Scrolling steps focus and pans; Monocle
    /// turns its front card; Floating drags one window.
    static func of(_ mode: LayoutMode, resting windows: Int) -> Self {
        let rest = Frame(windows: windows)
        var start = rest
        switch mode {
        case .bsp, .stack, .grid, .track:
            // The engine canvas draws any count, so a story may
            // start from one window (a 2 × 1 grid's 1 → 2).
            start.windows = max(1, windows - 1)
        case .scrolling:
            start.motion.focus = 1
        case .monocle:
            start.motion.turn = -1
        case .floating:
            start.motion.drag = 0
        }
        return Self(start: start, rest: rest)
    }
}
