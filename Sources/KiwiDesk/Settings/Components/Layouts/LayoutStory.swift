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
    /// its rest (a count already at its layout's floor) stays
    /// still.
    var plays: Bool { start != rest }

    /// `mode`'s story ending on `windows`, the count the surface
    /// draws at rest. Tiling layouts gain a window, which the
    /// engine places; Scrolling steps focus and pans; Monocle
    /// turns its front card; Floating drags one window.
    static func of(_ mode: LayoutMode, resting windows: Int) -> Self {
        let rest = Frame(windows: windows)
        var start = rest
        switch mode {
        case .bsp, .stack, .grid, .track:
            let floor = LayoutSchematic.windowCountRange(for: mode)
                .lowerBound
            start.windows = max(floor, windows - 1)
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
