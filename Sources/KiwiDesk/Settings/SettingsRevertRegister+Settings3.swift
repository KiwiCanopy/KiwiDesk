import KiwiDeskCore

/// The revert register's settings writers, part 3 (#792): one
/// per model-path key, written against its census id and held to
/// it by `SettingsRevertRegisterTests`.
extension SettingsRevertRegister {
    static let settings3: [SettingKey: RevertWriter] = [
        .layout(.gridRows): .leaf(\.settings.grid.rows),
        .layout(.gridNewWindowPlacement):
            .leaf(\.settings.grid.newWindowPlacement),
        .layout(.monocleOrientation): .leaf(\.settings.monocle.orientation),
        .layout(.monocleHideStyle): .leaf(\.settings.monocle.hideStyle),
        .layout(.monocleWrapFocus): .leaf(\.settings.monocle.wrapFocus),
        .layout(.monocleNewWindowPlacement):
            .leaf(\.settings.monocle.newWindowPlacement),
        .layout(.trackAxis): .leaf(\.settings.track.axis),
        .layout(.trackOverflowStyle): .leaf(\.settings.track.overflowStyle),
        .layout(.trackNewWindow): .leaf(\.settings.track.newWindow),
        .layout(.trackNewWindowPosition):
            .leaf(\.settings.track.newWindowPosition),
        .layout(.trackAutoTracks): .leaf(\.settings.track.autoTracks),
        .layout(.trackLimit): .leaf(\.settings.track.limit),
        .layout(.trackWrapFocus): .leaf(\.settings.track.wrapFocus),
        .layout(.bspOverrideStrategy):
            .entryField(
                \.settings.bsp.override,
                \.strategy,
                key: { SpaceID($0) }
            ),
        .layout(.bspOverrideSplitRatioH):
            .entryField(
                \.settings.bsp.override,
                \.splitRatioH,
                key: { SpaceID($0) }
            ),
        .layout(.bspOverrideSplitRatioV):
            .entryField(
                \.settings.bsp.override,
                \.splitRatioV,
                key: { SpaceID($0) }
            ),
        .layout(.stackOverrideMasterCount):
            .entryField(
                \.settings.stack.override,
                \.masterCount,
                key: { SpaceID($0) }
            ),
        .layout(.stackOverrideMasterRatio):
            .entryField(
                \.settings.stack.override,
                \.masterRatio,
                key: { SpaceID($0) }
            ),
        .layout(.stackOverrideOverflowStyle):
            .entryField(
                \.settings.stack.override,
                \.overflowStyle,
                key: { SpaceID($0) }
            ),
        .layout(.stackOverrideStackPosition):
            .entryField(
                \.settings.stack.override,
                \.stackPosition,
                key: { SpaceID($0) }
            ),
        .layout(.stackOverrideMasterOrientation):
            .entryField(
                \.settings.stack.override,
                \.masterOrientation,
                key: { SpaceID($0) }
            ),
        .layout(.scrollingOverrideOrientation):
            .entryField(
                \.settings.scrolling.override,
                \.orientation,
                key: { SpaceID($0) }
            ),
        .layout(.scrollingOverrideAnchor):
            .entryField(
                \.settings.scrolling.override,
                \.anchor,
                key: { SpaceID($0) }
            ),
        .layout(.scrollingOverrideSlotSize):
            .entryField(
                \.settings.scrolling.override,
                \.slotSize,
                key: { SpaceID($0) }
            ),
        .layout(.gridOverrideType):
            .entryField(
                \.settings.grid.override,
                \.type,
                key: { SpaceID($0) }
            ),
        .layout(.gridOverrideFillEmptyCells):
            .entryField(
                \.settings.grid.override,
                \.fillEmptyCells,
                key: { SpaceID($0) }
            ),
        .layout(.gridOverrideSplitDirection):
            .entryField(
                \.settings.grid.override,
                \.splitDirection,
                key: { SpaceID($0) }
            ),
        .layout(.gridOverrideColumns):
            .entryField(
                \.settings.grid.override,
                \.columns,
                key: { SpaceID($0) }
            ),
        .layout(.gridOverrideRows):
            .entryField(
                \.settings.grid.override,
                \.rows,
                key: { SpaceID($0) }
            ),
        .layout(.gridOverrideAutoSize):
            .entryField(
                \.settings.grid.override,
                \.autoSize,
                key: { SpaceID($0) }
            ),
        .layout(.gridOverrideColumnWeights):
            .entryField(
                \.settings.grid.override,
                \.columnWeights,
                key: { SpaceID($0) }
            ),
        .layout(.gridOverrideRowWeights):
            .entryField(
                \.settings.grid.override,
                \.rowWeights,
                key: { SpaceID($0) }
            ),
        .layout(.monocleOverrideOrientation):
            .entryField(
                \.settings.monocle.override,
                \.orientation,
                key: { SpaceID($0) }
            ),
        .layout(.trackOverrideAxis):
            .entryField(
                \.settings.track.override,
                \.axis,
                key: { SpaceID($0) }
            ),
        .layout(.trackOverrideLimit):
            .entryField(
                \.settings.track.override,
                \.limit,
                key: { SpaceID($0) }
            ),
        .layout(.trackOverrideOverflowStyle):
            .entryField(
                \.settings.track.override,
                \.overflowStyle,
                key: { SpaceID($0) }
            ),
        .layout(.trackOverrideAutoTracks):
            .entryField(
                \.settings.track.override,
                \.autoTracks,
                key: { SpaceID($0) }
            ),
        .layoutAppBar(.monocleAppBarVisibility):
            .leaf(\.settings.monocle.appBar.visibility),
        .layoutAppBar(.monocleAppBarActiveIndicator):
            .leaf(\.settings.monocle.appBar.activeIndicator),
        .layoutAppBar(.monocleAppBarTitleCap):
            .leaf(\.settings.monocle.appBar.titleCap),
        .layoutAppBar(.monocleAppBarGroupAdjacentWindows):
            .leaf(\.settings.monocle.appBar.groupAdjacentWindows),
        .layoutAppBar(.scrollingAppBarVisibility):
            .leaf(\.settings.scrolling.appBar.visibility),
        .layoutAppBar(.scrollingAppBarActiveIndicator):
            .leaf(\.settings.scrolling.appBar.activeIndicator),
        .layoutAppBar(.scrollingAppBarTitleCap):
            .leaf(\.settings.scrolling.appBar.titleCap),
        .layoutAppBar(.scrollingAppBarGroupAdjacentWindows):
            .leaf(\.settings.scrolling.appBar.groupAdjacentWindows),
        .spaceBar(.spaceBarReserve): .leaf(\.settings.spaceBarStyle.reserve),
        .spaceBar(.spaceBarVisibility):
            .leaf(\.settings.spaceBarStyle.visibility),
        .spaceBar(.spaceBarActiveIndicator):
            .leaf(\.settings.spaceBarStyle.activeIndicator),
        .spaceBar(.spaceBarHideEmpty):
            .leaf(\.settings.spaceBarStyle.hideEmpty),
        .spaceBar(.spaceBarGroupAdjacent):
            .leaf(\.settings.spaceBarStyle.groupAdjacentWindows),
        .spaceBar(.spaceBarShowFrontApp):
            .leaf(\.settings.spaceBarStyle.showFrontApp),
        .spaceBar(.spaceBarSpringDelay):
            .leaf(\.settings.spaceBarStyle.springDelay),
        .spaceBar(.spaceBarInactiveContent):
            .leaf(\.settings.spaceBarStyle.inactiveContent),
        .spaceBar(.spaceBarItemLabel):
            .leaf(\.settings.spaceBarStyle.itemLabel),
        .spaceBar(.spaceBarGlyphSpan):
            .leaf(\.settings.spaceBarStyle.glyphSpan),
        .spaceBar(.spaceBarGlyphGap): .leaf(\.settings.spaceBarStyle.glyphGap),
        .spaceBar(.spaceBarFrontAppTitleCap):
            .leaf(\.settings.spaceBarStyle.frontAppTitleCap),
        .spaceBar(.spaceBarActiveDimFactor):
            .leaf(\.settings.spaceBarStyle.activeDimFactor),
        .spaceBar(.spaceBarStickyBadge):
            .leaf(\.settings.spaceBarStyle.stickyBadge),
        .spaceBar(.spaceBarFocusedItemColor):
            .leaf(\.settings.spaceBarStyle.focusedItemColor),
        .spaceBar(.spaceBarFocusedHighlightColor):
            .leaf(\.settings.spaceBarStyle.focusedHighlightColor),
        .spaces(.spaceIcon):
            .entry(\.settings.spaceIcons, key: { SpaceID($0) }),
    ]
}
