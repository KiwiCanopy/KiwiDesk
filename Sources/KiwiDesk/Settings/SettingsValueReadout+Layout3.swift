import KiwiDeskCore

/// The Layout area's per-space override keys: each expands to
/// one row per space whose value for that FIELD differs, the
/// side that has no override reading as unset (— → 60 %). The
/// expansion machinery and the two axis-relative bespoke rows
/// live in `SettingsValueReadout+Layout4`.
extension SettingsValueReadout {
    static func layoutOverrideRows(
        _ key: LayoutKey,
        old: TilingSettings,
        new: TilingSettings
    ) -> [SettingsDiffRow] {
        let census = SettingKey.layout(key)
        switch key {
        case .bspOverrideStrategy:
            return layoutOvr(
                census,
                old.bsp.override,
                new.bsp.override,
                { $0.strategy },
                layoutStrategy
            )
        case .bspOverrideSplitRatioH:
            return layoutOvr(
                census,
                old.bsp.override,
                new.bsp.override,
                { $0.splitRatioH },
                percent
            )
        case .bspOverrideSplitRatioV:
            return layoutOvr(
                census,
                old.bsp.override,
                new.bsp.override,
                { $0.splitRatioV },
                percent
            )
        case .stackOverrideMasterCount:
            return layoutOvr(
                census,
                old.stack.override,
                new.stack.override,
                { $0.masterCount },
                layoutCount
            )
        case .stackOverrideMasterRatio:
            return layoutOvr(
                census,
                old.stack.override,
                new.stack.override,
                { $0.masterRatio },
                percent
            )
        case .stackOverrideMasterOrientation:
            return layoutOvr(
                census,
                old.stack.override,
                new.stack.override,
                { $0.masterOrientation }
            ) { layoutAxisWord(vertical: $0 == .vertical) }
        case .stackOverrideOverflowStyle:
            return layoutOvr(
                census,
                old.stack.override,
                new.stack.override,
                { $0.overflowStyle },
                layoutOverflow
            )
        case .stackOverrideStackPosition:
            return layoutOvr(
                census,
                old.stack.override,
                new.stack.override,
                { $0.stackPosition },
                layoutPosition
            )
        case .scrollingOverrideOrientation:
            return layoutOvr(
                census,
                old.scrolling.override,
                new.scrolling.override,
                { $0.orientation }
            ) { layoutAxisWord(vertical: $0 == .vertical) }
        case .scrollingOverrideAnchor:
            return layoutAnchorOvrRows(census, old: old, new: new)
        case .scrollingOverrideSlotSize:
            return layoutSlotOvrRows(census, old: old, new: new)
        case .gridOverrideType:
            return layoutOvr(
                census,
                old.grid.override,
                new.grid.override,
                { $0.type },
                layoutGridType
            )
        case .gridOverrideSplitDirection:
            return layoutOvr(
                census,
                old.grid.override,
                new.grid.override,
                { $0.splitDirection },
                layoutGridArrange
            )
        case .gridOverrideFillEmptySpace:
            return layoutOvr(
                census,
                old.grid.override,
                new.grid.override,
                { $0.fillEmptySpace },
                onOff
            )
        case .gridOverrideColumns:
            return layoutOvr(
                census,
                old.grid.override,
                new.grid.override,
                { $0.columns },
                layoutCount
            )
        case .gridOverrideRows:
            return layoutOvr(
                census,
                old.grid.override,
                new.grid.override,
                { $0.rows },
                layoutCount
            )
        case .gridOverrideAutoSize:
            // Lua-only, so its census text is `.none`; the base
            // label reuses the global twin's key.
            return layoutOvr(
                census,
                old.grid.override,
                new.grid.override,
                base: L("scroll_grid.auto_size", "Auto-size grid"),
                { $0.autoSize },
                onOff
            )
        case .monocleOverrideOrientation:
            return layoutOvr(
                census,
                old.monocle.override,
                new.monocle.override,
                { $0.orientation }
            ) { layoutAxisWord(vertical: $0 == .vertical) }
        case .trackOverrideAxis:
            return layoutOvr(
                census,
                old.track.override,
                new.track.override,
                { $0.axis },
                layoutTrackAxis
            )
        case .trackOverrideLimit:
            return layoutOvr(
                census,
                old.track.override,
                new.track.override,
                { $0.limit },
                layoutCount
            )
        case .trackOverrideOverflowStyle:
            return layoutOvr(
                census,
                old.track.override,
                new.track.override,
                { $0.overflowStyle },
                layoutOverflow
            )
        case .trackOverrideAutoTracks:
            // Lua-only twin of the grid case above.
            return layoutOvr(
                census,
                old.track.override,
                new.track.override,
                base: L("track.auto_tracks", "Auto track limit"),
                { $0.autoTracks },
                onOff
            )
        case .bspStrategy, .bspSplitRatioH, .bspSplitRatioV,
            .bspNewWindowPlacement, .stackMasterCount,
            .stackMasterRatio, .stackMasterOrientation,
            .stackStackPosition, .stackOverflowStyle,
            .stackNewWindowPlacement, .scrollingOrientation,
            .scrollingAnchor, .scrollingSlotSizeUnit,
            .scrollingSlotSizeValue,
            .scrollingNewWindowPlacement, .scrollingWrapFocus,
            .gridType, .gridSplitDirection, .gridFillEmptySpace,
            .gridAutoSize, .gridColumns, .gridRows,
            .gridNewWindowPlacement, .monocleOrientation,
            .monocleWrapFocus, .monocleNewWindowPlacement,
            .trackAxis, .trackOverflowStyle, .trackNewWindow,
            .trackNewWindowPosition, .trackAutoTracks,
            .trackLimit, .trackWrapFocus:
            // Globals — `layoutRows`' own switch narrates them;
            // this expander only ever receives override keys.
            // Spelled out (no `default:`) so a new census case
            // reds here too instead of falling through silently.
            return []
        }
    }
}
