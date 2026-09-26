import KiwiDeskCore

/// Bars catalog controls (#293, #277, #1517). Each drawer is
/// declared with its children so a search hit on a row behind the
/// disclosure opens it (#1250). The bar cards have no drawer: all
/// their rows are shown.
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
        "App Bar in %1$@",
        naming: .monocle
    )
    let scrollingShowIn = SettingsControl(
        "kiwishelf.show.scrolling",
        "App Bar in %1$@",
        naming: .scrolling
    )
    let spaceBarCard = SettingsControl(
        "bars.switch.space_bar",
        "Space Bar"
    )
    let appBarCard = SettingsControl(
        "bars.switch.app_bar",
        "App Bar"
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
    let kiwishelfStyleHighlightWidth = SettingsControl(
        "kiwishelf.highlight_width",
        "Highlight width"
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
    let kiwishelfStyleIconSource = SettingsControl(
        "kiwishelf.icon_source.label",
        "App symbol style"
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
