import KiwiDeskCore

/// The revert register's settings writers, part 2 (#792): one
/// per model-path key, written against its census id and held to
/// it by `SettingsRevertRegisterTests`.
extension SettingsRevertRegister {
    static let settings2: [SettingKey: RevertWriter] = [
        .gaps(.inner): .leaf(\.settings.gapsGlobal.inner),
        .gaps(.perSpaceOverride):
            .entry(\.settings.gapsOverride, key: { SpaceID($0) }),
        .kiwishelf(.thickness): .leaf(\.settings.kiwishelf.thickness),
        .kiwishelf(.alignment): .leaf(\.settings.kiwishelf.alignment),
        .kiwishelf(.order): .leaf(\.settings.kiwishelf.order),
        .kiwishelf(.minimum): .leaf(\.settings.kiwishelf.minimum),
        .kiwishelf(.background): .leaf(\.settings.kiwishelf.backgroundStyle),
        .kiwishelf(.backgroundFit): .leaf(\.settings.kiwishelf.backgroundFit),
        .kiwishelf(.cornerRoundness):
            .leaf(\.settings.kiwishelf.cornerRoundness),
        .kiwishelf(.border): .leaf(\.settings.kiwishelf.border),
        .kiwishelf(.borderWidth): .leaf(\.settings.kiwishelf.borderWidth),
        .kiwishelf(.highlightWidth):
            .leaf(\.settings.kiwishelf.highlightWidth),
        .kiwishelf(.itemGap): .leaf(\.settings.kiwishelf.itemGap),
        .kiwishelf(.glyphSizeAuto): .leaf(\.settings.kiwishelf.glyphSize),
        .kiwishelf(.glyphSize): .leaf(\.settings.kiwishelf.glyphSize),
        .kiwishelf(.fontSizeAuto): .leaf(\.settings.kiwishelf.fontSize),
        .kiwishelf(.fontSize): .leaf(\.settings.kiwishelf.fontSize),
        .kiwishelf(.fontFamily): .leaf(\.settings.kiwishelf.fontFamily),
        .kiwishelf(.fontWeight): .leaf(\.settings.kiwishelf.fontWeight),
        .kiwishelf(.outerMargin): .leaf(\.settings.kiwishelf.outerMargin),
        .kiwishelf(.innerMargin): .leaf(\.settings.kiwishelf.innerMargin),
        .kiwishelf(.liquidGlass): .leaf(\.settings.kiwishelf.liquidGlass),
        .kiwishelf(.iconSource): .leaf(\.settings.kiwishelf.iconSource),
        .kiwishelf(.dimFactor): .leaf(\.settings.kiwishelf.dimFactor),
        .kiwishelf(.revealDuration):
            .leaf(\.settings.kiwishelf.revealDuration),
        .kiwishelf(.fillColor): .leaf(\.settings.kiwishelf.fillColor),
        .kiwishelf(.borderColor): .leaf(\.settings.kiwishelf.borderColor),
        .kiwishelf(.itemColor): .leaf(\.settings.kiwishelf.itemColor),
        .kiwishelf(.activeItemColor):
            .leaf(\.settings.kiwishelf.activeItemColor),
        .kiwishelf(.highlightColor):
            .leaf(\.settings.kiwishelf.highlightColor),
        .kiwishelf(.hoverFillColor):
            .leaf(\.settings.kiwishelf.hoverFillColor),
        .kiwishelf(.hoverItemColor):
            .leaf(\.settings.kiwishelf.hoverItemColor),
        .kiwishelf(.groupBadgeColor):
            .leaf(\.settings.kiwishelf.groupBadgeColor),
        .kiwishelf(.groupBadgeTextColor):
            .leaf(\.settings.kiwishelf.groupBadgeTextColor),
        .layout(.bspStrategy): .leaf(\.settings.bsp.strategy),
        .layout(.bspSplitRatioH): .leaf(\.settings.bsp.splitRatioH),
        .layout(.bspSplitRatioV): .leaf(\.settings.bsp.splitRatioV),
        .layout(.bspNewWindowPlacement):
            .leaf(\.settings.bsp.newWindowPlacement),
        .layout(.stackMasterCount): .leaf(\.settings.stack.masterCount),
        .layout(.stackMasterRatio): .leaf(\.settings.stack.masterRatio),
        .layout(.stackMasterOrientation):
            .leaf(\.settings.stack.masterOrientation),
        .layout(.stackStackPosition): .leaf(\.settings.stack.stackPosition),
        .layout(.stackOverflowStyle): .leaf(\.settings.stack.overflowStyle),
        .layout(.stackNewWindowPlacement):
            .leaf(\.settings.stack.newWindowPlacement),
        .layout(.stackFillWhenAlone): .leaf(\.settings.stack.fillWhenAlone),
        .layout(.scrollingOrientation):
            .leaf(\.settings.scrolling.orientation),
        .layout(.scrollingAnchor): .leaf(\.settings.scrolling.anchor),
        .layout(.scrollingSlotSizeUnit): .leaf(\.settings.scrolling.slotSize),
        .layout(.scrollingSlotSizeValue): .leaf(\.settings.scrolling.slotSize),
        .layout(.scrollingSlotSizeCount): .leaf(\.settings.scrolling.slotSize),
        .layout(.scrollingNewWindowPlacement):
            .leaf(\.settings.scrolling.newWindowPlacement),
        .layout(.scrollingWrapFocus): .leaf(\.settings.scrolling.wrapFocus),
        .layout(.scrollingFillWhenAlone):
            .leaf(\.settings.scrolling.fillWhenAlone),
        .layout(.gridType): .leaf(\.settings.grid.type),
        .layout(.gridSplitDirection): .leaf(\.settings.grid.splitDirection),
        .layout(.gridFillEmptyCells): .leaf(\.settings.grid.fillEmptyCells),
        .layout(.gridAutoSize): .leaf(\.settings.grid.autoSize),
        .layout(.gridColumnWeights):
            .leaf(\.settings.grid.columnWeights),
        .layout(.gridRowWeights): .leaf(\.settings.grid.rowWeights),
        .layout(.gridColumns): .leaf(\.settings.grid.columns),
    ]
}
