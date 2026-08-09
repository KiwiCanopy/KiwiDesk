import KiwiDeskCore

/// The Layout area's row builders and value formatters, shared
/// by the global dispatch (`+Layout`) and the per-space override
/// expansion (`+Layout3`/`+Layout4`). Where one picker owns an
/// option's words, the labeller REUSES that picker's key
/// verbatim — key and English — so the diff and the row it
/// points at cannot drift apart in any locale. Orientation is
/// the deliberate exception: TWO picker families spell it
/// (`layout_params.orientation.*` for stack master, and
/// `scroll_grid.horizontal`/`vertical` for scrolling, grid and
/// monocle), so one diff key cannot match both and
/// `diff.value.orientation.*` stays the diff's own pair.
extension SettingsValueReadout {
    // MARK: - Row builders

    /// One scalar row: the census label plus the formatted pair.
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

    /// The pre-formatted variant (anchor, slot size — values
    /// whose words need more than the value itself).
    static func layoutTextRow(
        _ census: SettingKey,
        _ old: String,
        _ new: String
    ) -> [SettingsDiffRow] {
        layoutRow(census, old, new) { $0 }
    }

    // MARK: - Option labels (the pickers' own words)

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

    /// One pair for every orientation-shaped enum (stack master,
    /// scrolling, monocle) — the pickers all say these two words.
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

    /// Grid's Arrange words (#217): the GUI names the window
    /// arrangement, not the geometric wire vocabulary.
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

    /// Track's Arrange words: a vertical track is a column
    /// (#217 pattern), so the labels cross the wire's axis.
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

    // MARK: - Scrolling's axis-relative pieces

    /// The anchor's words come from the shared picker labeller,
    /// so Top/Left follow the orientation exactly as the
    /// segmented control spells them (#239, #753).
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
        // `.auto` presents as Percent, exactly as the unit
        // picker renders a stored auto (`SlotSizeRows.sizeUnit`).
        return L("diff.value.slot_unit.percent", "Percent")
    }

    /// `.auto` reads as the orientation standard's percentage —
    /// what the slot-size slider itself shows for a stored auto.
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

    /// The slot-size row's dynamic label, reusing the row's own
    /// keys so the diff and the slider agree per orientation.
    static func layoutSlotLabel(vertical: Bool) -> String {
        vertical
            ? L("slot_size.row_height", "Row height")
            : L("slot_size.column_width", "Column width")
    }

    /// A space's resolved scroll orientation (override beats the
    /// global) — which words its anchor and slot rows then use.
    static func layoutSpaceVertical(
        _ settings: TilingSettings,
        _ space: SpaceID
    ) -> Bool {
        (settings.scrolling.override[space]?.orientation
            ?? settings.scrolling.orientation) == .vertical
    }
}
