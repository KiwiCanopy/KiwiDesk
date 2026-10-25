import KiwiDeskCore

/// Behaviour settings diff readout generators.
extension SettingsValueReadout {
    static func behaviourRows(
        _ key: BehaviourKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        let census = SettingKey.behaviour(key)
        let before = old.settings
        let after = new.settings
        switch key {
        case .minWindowSize:
            return [
                .change(
                    census,
                    label: label(for: census),
                    old: minSizeSummary(before.minWindowSizes),
                    new: minSizeSummary(after.minWindowSizes)
                )
            ]
        case .minSizeStackWidth, .minSizeStackHeight,
            .minSizeGridWidth, .minSizeGridHeight,
            .minSizeTrackWidth, .minSizeTrackHeight,
            .minSizeBspWidth, .minSizeBspHeight,
            .minSizeScrollingWidth, .minSizeScrollingHeight,
            .minSizeFloatingWidth, .minSizeFloatingHeight:
            return minSizeRows(key, census, before, after)
        case .resizeStep:
            return [
                .change(
                    census,
                    label: L(
                        "diff.label.resize_step",
                        "Resize step"
                    ),
                    old: points(before.resizeStep),
                    new: points(after.resizeStep)
                )
            ]
        case .swapSkipsCascade:
            return [
                behaviourToggleRow(
                    census,
                    label: L(
                        "diff.label.swap_skips_cascade",
                        "Swap skips cascade"
                    ),
                    old: before.swapSkipsCascade,
                    new: after.swapSkipsCascade
                )
            ]
        case .floatPlacement:
            return [
                .change(
                    census,
                    label: L(
                        "diff.label.float_placement",
                        "Float placement"
                    ),
                    old: behaviourFloatPlacement(before.floatPlacement),
                    new: behaviourFloatPlacement(after.floatPlacement)
                )
            ]
        case .floatScaleOnDisplayChange:
            return [
                behaviourToggleRow(
                    census,
                    label: L(
                        "diff.label.float_scale_on_display_change",
                        "Scale floats across screens"
                    ),
                    old: before.floatScaleOnDisplayChange,
                    new: after.floatScaleOnDisplayChange
                )
            ]
        case .minSizePerSpaceOverride:
            return minSizeOverrideRows(
                census,
                old: before.minWindowSizeOverride,
                new: after.minWindowSizeOverride
            )
        case .placementOverride:
            return behaviourPlacementRows(
                census,
                old: before.placementOverride,
                new: after.placementOverride
            )
        case .mouseResize:
            return [
                .change(
                    census,
                    label: label(for: census),
                    old: behaviourMouseResize(before.mouseResize),
                    new: behaviourMouseResize(after.mouseResize)
                )
            ]
        case .mouseFollowsFocus:
            return [
                behaviourToggleRow(
                    census,
                    label: label(for: census),
                    old: before.mouse.followsFocus,
                    new: after.mouse.followsFocus
                )
            ]
        case .mouseHoverFocusDelay:
            return [
                .change(
                    census,
                    label: L(
                        "diff.label.hover_focus_delay",
                        "Hover focus delay"
                    ),
                    old: milliseconds(
                        Double(before.mouse.hoverFocusDelayMS)
                    ),
                    new: milliseconds(
                        Double(after.mouse.hoverFocusDelayMS)
                    )
                )
            ]
        case .mouseHoverFocus:
            return [
                behaviourToggleRow(
                    census,
                    label: label(for: census),
                    old: before.mouse.hoverFocus,
                    new: after.mouse.hoverFocus
                )
            ]
        case .kiwiHubKeyUp, .kiwiHubKeyDown, .kiwiHubKeyPageUp,
            .kiwiHubKeyPageDown, .kiwiHubKeyLeft, .kiwiHubKeyRight:
            return kiwiHubKeyRows(key, census, before, after)
        }
    }

    // MARK: - Helpers

    private static func behaviourToggleRow(
        _ census: SettingKey,
        label: String,
        old: Bool,
        new: Bool
    ) -> SettingsDiffRow {
        .change(
            census,
            label: label,
            old: onOff(old),
            new: onOff(new)
        )
    }

    /// One row per space whose spawn override moved, valued in
    /// the placement picker's own words.
    private static func behaviourPlacementRows(
        _ census: SettingKey,
        old: [SpaceID: SpawnPlacement],
        new: [SpaceID: SpawnPlacement]
    ) -> [SettingsDiffRow] {
        let base = L(
            "diff.label.placement_override",
            "Placement override"
        )
        let touched = Set(old.keys).union(new.keys)
            .filter { old[$0] != new[$0] }
            .sorted { $0.raw < $1.raw }
        return touched.map { space in
            .change(
                census,
                instance: space.raw,
                label: instanceLabel(base, space.raw),
                old: old[space].map(behaviourPlacement) ?? unset,
                new: new[space].map(behaviourPlacement) ?? unset
            )
        }
    }

    /// A row per Space whose own minimum window size was added,
    /// removed or edited (#2422).
    private static func minSizeOverrideRows(
        _ census: SettingKey,
        old: [SpaceID: MinSize],
        new: [SpaceID: MinSize]
    ) -> [SettingsDiffRow] {
        let base = L(
            "diff.label.min_size_override",
            "Minimum size override"
        )
        let touched = Set(old.keys).union(new.keys)
            .filter { old[$0] != new[$0] }
            .sorted { $0.raw < $1.raw }
        return touched.map { space in
            .change(
                census,
                instance: space.raw,
                label: instanceLabel(base, space.raw),
                old: old[space].map(minSize) ?? unset,
                new: new[space].map(minSize) ?? unset
            )
        }
    }

    /// `PlacementPicker`'s option labels, reused verbatim.
    private static func behaviourPlacement(
        _ placement: SpawnPlacement
    ) -> String {
        switch placement {
        case .first:
            return L("placement.first", "First")
        case .last:
            return L("placement.last", "Last")
        case .beforeFocused:
            return L(
                "placement.before_focused",
                "Before focused"
            )
        case .afterFocused:
            return L(
                "placement.after_focused",
                "After focused"
            )
        }
    }

    private static func behaviourFloatPlacement(
        _ placement: FloatPlacement
    ) -> String {
        switch placement {
        case .center:
            return L("diff.value.float_placement.center", "Centered")
        case .keep:
            return L("diff.value.float_placement.keep", "Kept in place")
        }
    }

    /// `BehaviorSection`'s segmented-picker labels, reused
    /// verbatim.
    private static func behaviourMouseResize(
        _ mode: MouseResizeMode
    ) -> String {
        switch mode {
        case .layout:
            return L(
                "behavior.mouse.resize_layout",
                "Resize adjacent windows"
            )
        case .snapBack:
            return L(
                "behavior.mouse.resize_snap_back",
                "Snap back to slot"
            )
        }
    }

    /// One per-layout axis of the minimum window size (#2237).
    private static func minSizeRows(
        _ key: BehaviourKey,
        _ census: SettingKey,
        _ before: TilingSettings,
        _ after: TilingSettings
    ) -> [SettingsDiffRow] {
        for layout in MinWindowSizes.Layout.allCases {
            for axis in MinSizeAxis.allCases
            where MinSizeText.key(layout, axis) == key {
                return [
                    .change(
                        census,
                        label: MinSizeText.name(layout, axis),
                        old: points(before.minWindowSizes[layout][axis]),
                        new: points(after.minWindowSizes[layout][axis])
                    )
                ]
            }
        }
        return []
    }

    /// The master's readout: the size every layout shares, or
    /// "Mixed" while they differ.
    private static func minSizeSummary(_ sizes: MinWindowSizes) -> String {
        guard let width = sizes.shared(.width),
            let height = sizes.shared(.height)
        else { return L("diff.value.mixed", "mixed") }
        return minSize(MinSize(width: width, height: height))
    }

}
