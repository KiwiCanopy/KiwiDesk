import KiwiDeskCore

/// The revert register's settings writers, part 1 (#792): one
/// per model-path key, written against its census id and held to
/// it by `SettingsRevertRegisterTests`.
extension SettingsRevertRegister {
    static let settings1: [SettingKey: RevertWriter] = [
        .appBar(.appBarActiveIndicator):
            .leaf(\.settings.appBarStyle.activeIndicator),
        .appBar(.appBarTitleCap): .leaf(\.settings.appBarStyle.titleCap),
        .appBar(.appBarGroupAdjacentWindows):
            .leaf(\.settings.appBarStyle.groupAdjacentWindows),
        .appBar(.appBarReserve): .leaf(\.settings.appBarStyle.reserve),
        .behaviour(.minWindowSize): .leaf(\.settings.minWindowSizes),
        .behaviour(.minSizeStackWidth):
            .leaf(\.settings.minWindowSizes.stack.width),
        .behaviour(.minSizeStackHeight):
            .leaf(\.settings.minWindowSizes.stack.height),
        .behaviour(.minSizeGridWidth):
            .leaf(\.settings.minWindowSizes.grid.width),
        .behaviour(.minSizeGridHeight):
            .leaf(\.settings.minWindowSizes.grid.height),
        .behaviour(.minSizeTrackWidth):
            .leaf(\.settings.minWindowSizes.track.width),
        .behaviour(.minSizeTrackHeight):
            .leaf(\.settings.minWindowSizes.track.height),
        .behaviour(.minSizeBspWidth):
            .leaf(\.settings.minWindowSizes.bsp.width),
        .behaviour(.minSizeBspHeight):
            .leaf(\.settings.minWindowSizes.bsp.height),
        .behaviour(.minSizeScrollingWidth):
            .leaf(\.settings.minWindowSizes.scrolling.width),
        .behaviour(.minSizeScrollingHeight):
            .leaf(\.settings.minWindowSizes.scrolling.height),
        .behaviour(.minSizeFloatingWidth):
            .leaf(\.settings.minWindowSizes.floating.width),
        .behaviour(.minSizeFloatingHeight):
            .leaf(\.settings.minWindowSizes.floating.height),
        .behaviour(.resizeStep): .leaf(\.settings.resizeStep),
        .behaviour(.swapSkipsCascade): .leaf(\.settings.swapSkipsCascade),
        .behaviour(.floatPlacement): .leaf(\.settings.floatPlacement),
        .behaviour(.floatScaleOnDisplayChange):
            .leaf(\.settings.floatScaleOnDisplayChange),
        .behaviour(.minSizePerSpaceOverride):
            .entry(\.settings.minWindowSizeOverride, key: { SpaceID($0) }),
        .behaviour(.placementOverride):
            .entry(\.settings.placementOverride, key: { SpaceID($0) }),
        .behaviour(.mouseResize): .leaf(\.settings.mouseResize),
        .behaviour(.mouseFollowsFocus): .leaf(\.settings.mouse.followsFocus),
        .behaviour(.mouseHoverFocus): .leaf(\.settings.mouse.hoverFocus),
        .behaviour(.mouseHoverFocusDelay):
            .leaf(\.settings.mouse.hoverFocusDelayMS),
        .borders(.borderEnabled): .leaf(\.settings.borderStyle.enabled),
        .borders(.borderFocusedColor):
            .leaf(\.settings.borderStyle.focusedColor),
        .borders(.borderUnfocusedEnabled):
            .leaf(\.settings.borderStyle.unfocusedEnabled),
        .borders(.borderUnfocusedColor):
            .leaf(\.settings.borderStyle.unfocusedColor),
        .borders(.borderWidth): .leaf(\.settings.borderStyle.width),
        .borders(.borderCorner): .leaf(\.settings.borderStyle.cornerStyle),
        .borders(.borderGlow): .leaf(\.settings.borderStyle.glow),
        .borders(.borderGlowSizeAuto): .leaf(\.settings.borderStyle.glowSize),
        .borders(.borderGlowSize): .leaf(\.settings.borderStyle.glowSize),
        .borders(.borderDrawOrder): .leaf(\.settings.borderStyle.drawOrder),
        .borders(.stickyMark): .leaf(\.settings.stickyStyle.mark),
        .borders(.stickyColor): .leaf(\.settings.stickyStyle.color),
        .borders(.stickyDesktopReach):
            .leaf(\.settings.stickyStyle.desktopReach),
        .borders(.floatingMark): .leaf(\.settings.floatingStyle.mark),
        .borders(.dragGhostEnabled): .leaf(\.settings.dragGhost.enabled),
        .borders(.dragGhostBorder): .leaf(\.settings.dragGhost.border),
        .borders(.dragGhostBorderColor):
            .leaf(\.settings.dragGhost.borderColor),
        .borders(.dragGhostBorderAlignment):
            .leaf(\.settings.dragGhost.borderAlignment),
        .borders(.dragGhostFill): .leaf(\.settings.dragGhost.fill),
        .borders(.dragGhostFillColor): .leaf(\.settings.dragGhost.fillColor),
        .borders(.dragDropZoneEnabled): .leaf(\.settings.dragDropZone.enabled),
        .borders(.dragDropZoneBorder): .leaf(\.settings.dragDropZone.border),
        .borders(.dragDropZoneBorderColor):
            .leaf(\.settings.dragDropZone.borderColor),
        .borders(.dragDropZoneBorderAlignment):
            .leaf(\.settings.dragDropZone.borderAlignment),
        .borders(.dragDropZoneFill): .leaf(\.settings.dragDropZone.fill),
        .borders(.dragDropZoneFillColor):
            .leaf(\.settings.dragDropZone.fillColor),
        .borders(.floatingColor): .leaf(\.settings.floatingStyle.color),
        .colours(.shortcutPanelLiquidGlass):
            .leaf(\.settings.shortcutPanelLiquidGlass),
        .colours(.dragLiquidGlass): .leaf(\.settings.dragLiquidGlass),
        .colours(.stickyLiquidGlass):
            .leaf(\.settings.stickyStyle.liquidGlass),
        .colours(.borderSheen): .leaf(\.settings.borderStyle.sheen),
        .colours(.animationsMaster): .leaf(\.settings.animations),
        .colours(.animationsOnWindowResize):
            .leaf(\.settings.animations.onWindowResize),
        .colours(.animationsOnWindowSwap):
            .leaf(\.settings.animations.onWindowSwap),
        .colours(.animationsOnRelayout):
            .leaf(\.settings.animations.onRelayout),
        .colours(.animationsDurationMS):
            .leaf(\.settings.animations.durationMS),
        .colours(.animationsOnScrolling):
            .leaf(\.settings.animations.onScrolling),
        .colours(.animationsScrollDurationMS):
            .leaf(\.settings.animations.scrollDurationMS),
        .colours(.animationsOnShelf): .leaf(\.settings.animations.onShelf),
        .colours(.animationsShelfDurationMS):
            .leaf(\.settings.animations.shelfDurationMS),
        .gaps(.outerTop): .leaf(\.settings.gapsGlobal.outer.top),
        .gaps(.outerBottom): .leaf(\.settings.gapsGlobal.outer.bottom),
        .gaps(.outerLeft): .leaf(\.settings.gapsGlobal.outer.left),
        .gaps(.outerRight): .leaf(\.settings.gapsGlobal.outer.right),
        .gaps(.innerHorizontal): .leaf(\.settings.gapsGlobal.inner.horizontal),
        .gaps(.innerVertical): .leaf(\.settings.gapsGlobal.inner.vertical),
        .gaps(.outer): .leaf(\.settings.gapsGlobal.outer),
    ]
}
