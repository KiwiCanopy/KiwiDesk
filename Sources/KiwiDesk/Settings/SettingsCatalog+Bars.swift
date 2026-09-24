import KiwiDeskCore

/// Bars catalog controls (#293, #277, #1517). Each drawer is
/// declared with its children so a search hit on a row behind the
/// disclosure opens it (#1250): the bars' Style drawers share one
/// label key, so the CHILDREN carry each card's own keys and the
/// join lands on the right card's row.
struct BarsControls: Sendable {
    let kiwishelfCard = SettingsControl(
        "bars.switch.kiwishelf",
        "KiwiShelf"
    )
    let kiwishelfStyle = SettingsDrawer(
        "bars.style",
        "Style",
        instance: "kiwishelf",
        children: KiwiShelfStyleControls()
    )
    let kiwishelfMargins = SettingsDrawer(
        "kiwishelf.margins",
        "Margins",
        instance: "kiwishelf",
        children: KiwiShelfMarginControls()
    )
    let monocleShowIn = SettingsControl(
        "kiwishelf.show.monocle",
        "App Bar in Monocle"
    )
    let scrollingShowIn = SettingsControl(
        "kiwishelf.show.scrolling",
        "App Bar in Scrolling"
    )
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
}

/// KiwiShelf ▸ Style rows, keyed on their census label keys and
/// declared in `BarsRowOrder.kiwishelfStyle`'s order.
struct KiwiShelfStyleControls: Sendable {
    let kiwishelfStyleBackground = SettingsControl(
        "kiwishelf.background_style.label",
        "Background style"
    )
    let kiwishelfStyleBackgroundFit = SettingsControl(
        "kiwishelf.background_fit.label",
        "Background size"
    )
    let kiwishelfStyleCornerRoundness = SettingsControl(
        "kiwishelf.corner_roundness",
        "Corner roundness"
    )
    let kiwishelfStyleItemGap = SettingsControl(
        "kiwishelf.item_gap",
        "Item gap"
    )
    let kiwishelfStyleFontSizeAuto = SettingsControl(
        "kiwishelf.font_size.auto",
        "Auto font size"
    )
    let kiwishelfStyleFontSize = SettingsControl(
        "kiwishelf.font_size",
        "Font size"
    )
}

/// KiwiShelf ▸ Margins rows, in `BarsRowOrder.kiwishelfMargins`'
/// order.
struct KiwiShelfMarginControls: Sendable {
    let kiwishelfOuterMargin = SettingsControl(
        "kiwishelf.outer_margin",
        "Outer margin"
    )
    let kiwishelfInnerMargin = SettingsControl(
        "kiwishelf.inner_margin",
        "Inner margin"
    )
}

/// Space Bar ▸ Style rows, keyed on their census label keys and
/// declared in `BarsRowOrder.spaceBarStyle`'s order.
struct SpaceBarStyleControls: Sendable {
    let spaceBarStyleActiveIndicator = SettingsControl(
        "space_bar.active_indicator.label",
        "Active indicator"
    )
    let spaceBarStyleIconSource = SettingsControl(
        "space_bar.icon_source.label",
        "App symbol style"
    )
    let spaceBarStyleGlyphCap = SettingsControl(
        "space_bar.glyph_cap",
        "Glyphs per Space"
    )
    let spaceBarStyleFrontAppTitleCap = SettingsControl(
        "space_bar.front_app_title_cap",
        "Front app title length"
    )
    let spaceBarStyleSpringDelay = SettingsControl(
        "space_bar.spring_delay",
        "Spring delay"
    )
}

/// App Bar ▸ Style rows, keyed on their census label keys and
/// declared in `BarsRowOrder.appBarStyle`'s order.
struct AppBarStyleControls: Sendable {
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
}
