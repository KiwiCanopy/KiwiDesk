import KiwiDeskCore

/// Layout Defaults rows — the six layouts' global parameters.
/// Every value narrates the unit its own Settings row shows:
/// ratios as the slider's percentage readout, the slot size in
/// its picked unit, enum options in the pickers' own words
/// (`SettingsValueReadout+Layout2` holds those formatters). The
/// per-space override keys expand to one row per touched space
/// in `SettingsValueReadout+Layout3`.
extension SettingsValueReadout {
    static func layoutRows(
        _ key: LayoutKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        let census = SettingKey.layout(key)
        let o = old.settings
        let n = new.settings
        switch key {
        case .bspStrategy:
            return layoutRow(
                census,
                o.bsp.strategy,
                n.bsp.strategy,
                layoutStrategy
            )
        case .bspSplitRatioH:
            return layoutRow(
                census,
                o.bsp.splitRatioH,
                n.bsp.splitRatioH,
                percent
            )
        case .bspSplitRatioV:
            return layoutRow(
                census,
                o.bsp.splitRatioV,
                n.bsp.splitRatioV,
                percent
            )
        case .bspNewWindowPlacement:
            return layoutRow(
                census,
                o.bsp.newWindowPlacement,
                n.bsp.newWindowPlacement,
                layoutPlacement
            )
        case .stackMasterCount:
            return layoutRow(
                census,
                o.stack.masterCount,
                n.stack.masterCount,
                layoutCount
            )
        case .stackMasterRatio:
            return layoutRow(
                census,
                o.stack.masterRatio,
                n.stack.masterRatio,
                percent
            )
        case .stackMasterOrientation:
            return layoutRow(
                census,
                o.stack.masterOrientation,
                n.stack.masterOrientation
            ) { layoutAxisWord(vertical: $0 == .vertical) }
        case .stackStackPosition:
            return layoutRow(
                census,
                o.stack.stackPosition,
                n.stack.stackPosition,
                layoutPosition
            )
        case .stackOverflowStyle:
            return layoutRow(
                census,
                o.stack.overflowStyle,
                n.stack.overflowStyle,
                layoutOverflow
            )
        case .stackNewWindowPlacement:
            return layoutRow(
                census,
                o.stack.newWindowPlacement,
                n.stack.newWindowPlacement,
                layoutPlacement
            )
        case .scrollingOrientation:
            return layoutRow(
                census,
                o.scrolling.orientation,
                n.scrolling.orientation
            ) { layoutAxisWord(vertical: $0 == .vertical) }
        case .scrollingAnchor:
            return layoutTextRow(
                census,
                layoutAnchorText(
                    o.scrolling.anchor,
                    vertical: !o.scrolling.axisIsHorizontal
                ),
                layoutAnchorText(
                    n.scrolling.anchor,
                    vertical: !n.scrolling.axisIsHorizontal
                )
            )
        case .scrollingSlotSizeUnit:
            return layoutTextRow(
                census,
                layoutSlotUnit(o.scrolling.slotSize),
                layoutSlotUnit(n.scrolling.slotSize)
            )
        case .scrollingSlotSizeValue:
            // The row's label is dynamic in the census (Column
            // width / Row height); compose it from the draft's
            // orientation, and read each side's value in that
            // side's own unit.
            return [
                .change(
                    census,
                    label: layoutSlotLabel(
                        vertical: !n.scrolling.axisIsHorizontal
                    ),
                    old: layoutSlotValue(
                        o.scrolling.slotSize,
                        vertical: !o.scrolling.axisIsHorizontal
                    ),
                    new: layoutSlotValue(
                        n.scrolling.slotSize,
                        vertical: !n.scrolling.axisIsHorizontal
                    )
                )
            ]
        case .scrollingNewWindowPlacement:
            return layoutRow(
                census,
                o.scrolling.newWindowPlacement,
                n.scrolling.newWindowPlacement,
                layoutPlacement
            )
        case .scrollingWrapFocus:
            return layoutRow(
                census,
                o.scrolling.wrapFocus,
                n.scrolling.wrapFocus,
                onOff
            )
        case .gridType:
            return layoutRow(
                census,
                o.grid.type,
                n.grid.type,
                layoutGridType
            )
        case .gridSplitDirection:
            return layoutRow(
                census,
                o.grid.splitDirection,
                n.grid.splitDirection,
                layoutGridArrange
            )
        case .gridFillEmptyCells:
            return layoutRow(
                census,
                o.grid.fillEmptyCells,
                n.grid.fillEmptyCells,
                onOff
            )
        case .gridAutoSize:
            return layoutRow(
                census,
                o.grid.autoSize,
                n.grid.autoSize,
                onOff
            )
        case .gridColumns:
            return layoutRow(
                census,
                o.grid.columns,
                n.grid.columns,
                layoutCount
            )
        case .gridRows:
            return layoutRow(
                census,
                o.grid.rows,
                n.grid.rows,
                layoutCount
            )
        case .gridNewWindowPlacement:
            return layoutRow(
                census,
                o.grid.newWindowPlacement,
                n.grid.newWindowPlacement,
                layoutPlacement
            )
        case .monocleOrientation:
            return layoutRow(
                census,
                o.monocle.orientation,
                n.monocle.orientation
            ) { layoutAxisWord(vertical: $0 == .vertical) }
        case .monocleWrapFocus:
            return layoutRow(
                census,
                o.monocle.wrapFocus,
                n.monocle.wrapFocus,
                onOff
            )
        case .monocleNewWindowPlacement:
            return layoutRow(
                census,
                o.monocle.newWindowPlacement,
                n.monocle.newWindowPlacement,
                layoutPlacement
            )
        case .trackAxis:
            return layoutRow(
                census,
                o.track.axis,
                n.track.axis,
                layoutTrackAxis
            )
        case .trackOverflowStyle:
            return layoutRow(
                census,
                o.track.overflowStyle,
                n.track.overflowStyle,
                layoutOverflow
            )
        case .trackNewWindow:
            return layoutRow(
                census,
                o.track.newWindow,
                n.track.newWindow,
                layoutTrackWindow
            )
        case .trackNewWindowPosition:
            return layoutRow(
                census,
                o.track.newWindowPosition,
                n.track.newWindowPosition,
                layoutPlacement
            )
        case .trackAutoTracks:
            return layoutRow(
                census,
                o.track.autoTracks,
                n.track.autoTracks,
                onOff
            )
        case .trackLimit:
            return layoutRow(
                census,
                o.track.limit,
                n.track.limit,
                layoutCount
            )
        case .trackWrapFocus:
            return layoutRow(
                census,
                o.track.wrapFocus,
                n.track.wrapFocus,
                onOff
            )
        case .bspOverrideStrategy, .bspOverrideSplitRatioH,
            .bspOverrideSplitRatioV, .stackOverrideMasterCount,
            .stackOverrideMasterRatio,
            .stackOverrideMasterOrientation,
            .stackOverrideOverflowStyle,
            .stackOverrideStackPosition,
            .scrollingOverrideOrientation,
            .scrollingOverrideAnchor, .scrollingOverrideSlotSize,
            .gridOverrideType, .gridOverrideSplitDirection,
            .gridOverrideFillEmptyCells, .gridOverrideColumns,
            .gridOverrideRows, .gridOverrideAutoSize,
            .monocleOverrideOrientation, .trackOverrideAxis,
            .trackOverrideLimit, .trackOverrideOverflowStyle,
            .trackOverrideAutoTracks:
            return layoutOverrideRows(key, old: o, new: n)
        }
    }
}
