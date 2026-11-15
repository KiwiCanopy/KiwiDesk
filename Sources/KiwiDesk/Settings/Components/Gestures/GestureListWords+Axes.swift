import KiwiDeskCore

/// A swipe's axis words (#1873 ▸ Ruling 2026-11-15, the split
/// editor): the axis sub-rows' names and glyphs, the row's "Per
/// axis" face and the Natural scrolling caption.
extension GestureListWords {
    static func axis(_ axis: GestureAxis) -> String {
        switch axis {
        case .leftRight:
            L("shortcuts.gestures.axis.left_right", "Left and right")
        case .upDown: L("shortcuts.gestures.axis.up_down", "Up and down")
        }
    }

    static func axis(symbol axis: GestureAxis) -> String {
        switch axis {
        case .leftRight: "arrow.left.and.right"
        case .upDown: "arrow.up.and.down"
        }
    }

    /// A split row's face: per axis while every axis it binds runs
    /// a family, per direction once one runs actions of its own.
    static func face(
        _ split: GestureSplit,
        on input: GestureInput
    ) -> String {
        guard split.arms.isEmpty else { return perDirection(input) }
        return L("shortcuts.gestures.per_axis", "Per axis")
    }

    /// The grey caption under a swipe row that mixes an axis family
    /// with fixed directions, drawn only while Natural scrolling is
    /// on, since with it off nothing turns either way (gui.md).
    static func naturalCaption(_ split: GestureSplit) -> String? {
        guard !split.arms.isEmpty else { return nil }
        let families = GestureAxis.allCases.filter {
            split.axes[$0] != nil
        }
        guard families.count == 1, let follows = families.first else {
            return L(
                "shortcuts.gestures.natural.fixed",
                "Each direction keeps the way you set it, whatever "
                    + "Natural scrolling says."
            )
        }
        return follows == .leftRight
            ? L(
                "shortcuts.gestures.natural.left_right",
                "Left and right follow Natural scrolling. Up and down "
                    + "keep the way you set them."
            )
            : L(
                "shortcuts.gestures.natural.up_down",
                "Up and down follow Natural scrolling. Left and right "
                    + "keep the way you set them."
            )
    }
}
