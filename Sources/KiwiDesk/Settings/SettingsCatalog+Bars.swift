import KiwiDeskCore

/// Bars catalog controls (#293, #277). Each bar's Style drawer
/// is declared with its children so a search hit on a row
/// behind the disclosure opens it (#1250): the two drawers share
/// one label key, so the CHILDREN carry the bar's own keys and
/// the join lands on the right bar's row.
struct BarsControls: Sendable {
    let spaceBarCard = SettingsControl(
        "bars.switch.space_bar",
        "Space Bar"
    )
    let spaceBarStyle = SettingsDrawer(
        "bars.style",
        "Style",
        instance: "space_bar",
        children: SpaceBarStyleControls()
    )
    let appBarCard = SettingsControl(
        "bars.switch.app_bar",
        "App Bar"
    )
    let appBarStyle = SettingsDrawer(
        "bars.style",
        "Style",
        instance: "app_bar",
        children: AppBarStyleControls()
    )
    let monocleShowIn = SettingsControl(
        "layout.monocle.name",
        "Monocle"
    )
    let scrollingShowIn = SettingsControl(
        "layout.scrolling.name",
        "Scrolling"
    )
}

/// Space Bar ▸ Style rows, keyed on their census label keys and
/// declared in `BarsRowOrder.spaceBarStyle`'s order.
struct SpaceBarStyleControls: Sendable {
    let spaceBarStyleBackground = SettingsControl(
        "space_bar.background_style.label",
        "Background style"
    )
    let spaceBarStyleBackgroundFit = SettingsControl(
        "space_bar.background_fit.label",
        "Background size"
    )
    let spaceBarStyleAlignment = SettingsControl(
        "space_bar.alignment.label",
        "Alignment"
    )
    let spaceBarStyleActiveIndicator = SettingsControl(
        "space_bar.active_indicator.label",
        "Active indicator"
    )
    let spaceBarStyleIconSource = SettingsControl(
        "space_bar.icon_source.label",
        "App symbol style"
    )
    let spaceBarStyleCornerRoundness = SettingsControl(
        "space_bar.corner_roundness",
        "Corner roundness"
    )
    let spaceBarStyleItemSizeAuto = SettingsControl(
        "space_bar.item_size.auto",
        "Auto item size"
    )
    let spaceBarStyleItemSize = SettingsControl(
        "space_bar.item_size",
        "Item size"
    )
    let spaceBarStyleItemGap = SettingsControl(
        "space_bar.item_gap",
        "Item gap"
    )
    let spaceBarStyleOuterMargin = SettingsControl(
        "space_bar.outer_margin",
        "Outer margin"
    )
    let spaceBarStyleInnerMargin = SettingsControl(
        "space_bar.inner_margin",
        "Inner margin"
    )
    let spaceBarStyleFontSizeAuto = SettingsControl(
        "space_bar.font_size.auto",
        "Auto font size"
    )
    let spaceBarStyleFontSize = SettingsControl(
        "space_bar.font_size",
        "Font size"
    )
    let spaceBarStyleGlyphCap = SettingsControl(
        "space_bar.glyph_cap",
        "Glyphs per Space"
    )
    let spaceBarStyleTitleCap = SettingsControl(
        "space_bar.title_cap",
        "Title length"
    )
    let spaceBarStyleSpringDelay = SettingsControl(
        "space_bar.spring_delay",
        "Spring delay"
    )
}

/// App Bar ▸ Style rows, keyed on their census label keys and
/// declared in `BarsRowOrder.appBarStyle`'s order.
struct AppBarStyleControls: Sendable {
    let appBarStyleBackground = SettingsControl(
        "app_bar.background_style.label",
        "Background style"
    )
    let appBarStyleBackgroundFit = SettingsControl(
        "app_bar.background_fit.label",
        "Background size"
    )
    let appBarStyleAlignment = SettingsControl(
        "app_bar.alignment.label",
        "Alignment"
    )
    let appBarStyleActiveIndicator = SettingsControl(
        "app_bar.active_indicator.label",
        "Active indicator"
    )
    let appBarStyleContent = SettingsControl(
        "app_bar.content.label",
        "Content"
    )
    let appBarStyleTitleCap = SettingsControl(
        "app_bar.title_cap",
        "Title length"
    )
    let appBarStyleIconSource = SettingsControl(
        "app_bar.icon_source.label",
        "App symbol style"
    )
    let appBarStyleCornerRoundness = SettingsControl(
        "app_bar.corner_roundness",
        "Corner roundness"
    )
    let appBarStyleItemSizeAuto = SettingsControl(
        "app_bar.item_size.auto",
        "Auto item size"
    )
    let appBarStyleItemSize = SettingsControl(
        "app_bar.item_size",
        "Item size"
    )
    let appBarStyleItemGap = SettingsControl(
        "app_bar.item_gap",
        "Item gap"
    )
    let appBarStyleOuterMargin = SettingsControl(
        "app_bar.outer_margin",
        "Outer margin"
    )
    let appBarStyleInnerMargin = SettingsControl(
        "app_bar.inner_margin",
        "Inner margin"
    )
    let appBarStyleFontSizeAuto = SettingsControl(
        "app_bar.font_size.auto",
        "Auto font size"
    )
    let appBarStyleFontSize = SettingsControl(
        "app_bar.font_size",
        "Font size"
    )
}
