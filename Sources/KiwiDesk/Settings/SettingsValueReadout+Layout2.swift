import KiwiDeskCore

/// Layout area diff row builders and value formatters. Where one
/// picker owns an option's words, the labeller REUSES that
/// picker's key verbatim so the diff and the row cannot drift in
/// any locale. Orientation is the deliberate exception: TWO
/// picker families spell it, so one diff key cannot match both
/// and `diff.value.orientation.*` stays the diff's own pair.
extension SettingsValueReadout {
    /// Formats scalar layout diff row.
    static func layoutRow<V>(
        _ census: SettingKey,
        _ old: V,
        _ new: V,
        _ text: @MainActor (V) -> String
    ) -> [SettingsDiffRow] {
        [
            .change(
                census,
                label: label(for: census),
                old: text(old),
                new: text(new)
            )
        ]
    }

    /// Formats pre-rendered text diff row.
    static func layoutTextRow(
        _ census: SettingKey,
        _ old: String,
        _ new: String
    ) -> [SettingsDiffRow] {
        layoutRow(census, old, new) { $0 }
    }

    static func layoutStrategy(
        _ value: BspParams.Strategy
    ) -> String {
        switch value {
        case .longestSide:
            return L(
                "layout_params.longest_side",
                "Longest side"
            )
        case .alternating:
            return L("layout_params.alternating", "Alternating")
        }
    }

    static func layoutPlacement(
        _ value: SpawnPlacement
    ) -> String {
        switch value {
        case .first:
            return L("diff.value.placement.first", "First")
        case .last:
            return L("diff.value.placement.last", "Last")
        case .beforeFocused:
            return L(
                "diff.value.placement.before_focused",
                "Before focused"
            )
        case .afterFocused:
            return L(
                "diff.value.placement.after_focused",
                "After focused"
            )
        }
    }

    /// Localized axis label for orientation-shaped layout properties.
    static func layoutAxisWord(vertical: Bool) -> String {
        vertical
            ? L("diff.value.orientation.vertical", "Vertical")
            : L(
                "diff.value.orientation.horizontal",
                "Horizontal"
            )
    }

    static func layoutPosition(
        _ value: StackParams.StackPosition
    ) -> String {
        switch value {
        case .top:
            return L("layout_params.position.top", "Top")
        case .right:
            return L("layout_params.position.right", "Right")
        case .bottom:
            return L("layout_params.position.bottom", "Bottom")
        case .left:
            return L("layout_params.position.left", "Left")
        }
    }

    static func layoutOverflow(
        _ value: StackParams.OverflowStyle
    ) -> String {
        switch value {
        case .cascadeOverflow:
            return L(
                "layout_params.cascade_overflow",
                "Cascade overflow"
            )
        case .cascadeAll:
            return L("layout_params.cascade_all", "Cascade all")
        }
    }

    /// Localized monocle hide style option text (#881).
    static func layoutHideStyle(
        _ value: MonocleParams.HideStyle
    ) -> String {
        switch value {
        case .stack:
            return L("monocle.hide_style.stack", "Stack behind")
        case .park:
            return L(
                "monocle.hide_style.park",
                "Park in corner"
            )
        }
    }

    static func layoutGridType(
        _ value: GridParams.GridType
    ) -> String {
        switch value {
        case .dynamic:
            return L("scroll_grid.dynamic", "Dynamic")
        case .rigid:
            return L("scroll_grid.rigid", "Rigid")
        }
    }

    /// Localized grid arrange option text (#217).
    static func layoutGridArrange(
        _ value: GridParams.SplitDirection
    ) -> String {
        switch value {
        case .horizontal:
            return L(
                "scroll_grid.arrange.columns_first",
                "Columns first"
            )
        case .vertical:
            return L(
                "scroll_grid.arrange.rows_first",
                "Rows first"
            )
        }
    }

    /// Localized track axis arrange option text (#217).
    static func layoutTrackAxis(
        _ value: TrackParams.Axis
    ) -> String {
        switch value {
        case .vertical:
            return L("scroll_grid.arrange.columns", "Columns")
        case .horizontal:
            return L("scroll_grid.arrange.rows", "Rows")
        }
    }

    static func layoutTrackWindow(
        _ value: TrackParams.NewWindowTrack
    ) -> String {
        switch value {
        case .focusedTrack:
            return L(
                "diff.value.track_new_window.focused",
                "Fills the focused track"
            )
        case .ownTrack:
            return L(
                "diff.value.track_new_window.own",
                "Opens its own track"
            )
        }
    }

    static func layoutCount(_ value: Int) -> String {
        String(value)
    }

    /// Localized scroll anchor text (`ScrollAnchorLabel`, #239, #753).
    static func layoutAnchorText(
        _ anchor: ScrollingParams.Anchor,
        vertical: Bool
    ) -> String {
        ScrollAnchorLabel.text(for: anchor, isVertical: vertical)
    }

    static func layoutSlotUnit(_ size: ScrollSize) -> String {
        if case .points = size {
            return L("diff.value.slot_unit.points", "Points")
        }
        return L("diff.value.slot_unit.percent", "Percent")
    }

    /// Formats scroll slot size value as points or percent (`ScrollSize`).
    static func layoutSlotValue(
        _ size: ScrollSize,
        vertical: Bool
    ) -> String {
        switch size {
        case .points(let value):
            return points(value)
        case .fraction(let fraction):
            return percent(fraction)
        case .auto:
            return percent(
                vertical
                    ? ScrollSize.autoVerticalFraction
                    : ScrollSize.autoHorizontalFraction
            )
        }
    }

    /// Localized slot size row label based on scroll orientation.
    static func layoutSlotLabel(vertical: Bool) -> String {
        vertical
            ? L("slot_size.row_height", "Row height")
            : L("slot_size.column_width", "Column width")
    }

    /// Resolves effective scroll orientation for a space
    /// (`TilingSettings`, `SpaceID`).
    static func layoutSpaceVertical(
        _ settings: TilingSettings,
        _ space: SpaceID
    ) -> Bool {
        (settings.scrolling.override[space]?.orientation
            ?? settings.scrolling.orientation) == .vertical
    }
}
