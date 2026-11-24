import KiwiDeskCore

/// Bars catalog controls (#293, #277, #1517). Each drawer is
/// declared with its children so a search hit on a row behind the
/// disclosure opens it (#1250). The App Bar card has no drawer;
/// the Space Bar card keeps its numbers in Fine-tuning (#2507).
struct BarsControls: Sendable {
    let kiwishelfCard = SettingsControl(
        "bars.switch.kiwishelf",
        "KiwiShelf"
    )
    let kiwishelfEach = SettingsDrawer(
        "kiwishelf.show.each_bar",
        "Each bar and Pocket",
        instance: "kiwishelf",
        children: KiwiShelfEachControls()
    )
    let kiwishelfStyle = SettingsDrawer(
        "bars.style",
        "Style",
        instance: "kiwishelf",
        children: KiwiShelfStyleControls()
    )
    let kiwishelfDurations = SettingsDrawer(
        "kiwishelf.durations",
        "Durations",
        instance: "kiwishelf",
        children: KiwiShelfDurationControls()
    )
    let kiwishelfMargins = SettingsDrawer(
        "kiwishelf.margins",
        "Margins",
        instance: "kiwishelf",
        children: KiwiShelfMarginControls()
    )
    /// The heading over what plays while a bar is out of view
    /// (#3612): menu bar icon, handle, Reveal and Durations.
    let kiwishelfOutOfView = SettingsControl(
        "kiwishelf.out_of_view",
        "When a bar is out of view"
    )
    let kiwishelfHandleThickness = SettingsControl(
        "kiwishelf.handle_thickness",
        "Handle thickness"
    )
    let kiwishelfMenuBarIcon = SettingsControl(
        "kiwishelf.menu_bar_icon",
        "Menu bar icon"
    )
    let kiwishelfRevealStyle = SettingsControl(
        "kiwishelf.reveal_style.label",
        "Reveal"
    )
    let spaceBarCard = SettingsControl(
        "bars.switch.space_bar",
        "Space Bar"
    )
    let spaceBarTuning = SettingsDrawer(
        "space_bar.fine_tuning",
        "Fine-tuning",
        instance: "space_bar",
        children: SpaceBarTuningControls()
    )
    let appBarCard = SettingsControl(
        "bars.switch.app_bar",
        "App Bar"
    )
}

/// KiwiShelf ▸ Durations rows (owner ruling, 2026-10-21),
/// in `BarsRowOrder.kiwishelfDurations`' order.
struct KiwiShelfDurationControls: Sendable {
    let onReveal = SettingsControl(
        "kiwishelf.on_reveal",
        "Animate the reveal"
    )
    let onExpand = SettingsControl(
        "kiwishelf.on_expand",
        "Animate the expand"
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
    let kiwishelfStyleBorder = SettingsControl(
        "kiwishelf.border",
        "Border"
    )
    let kiwishelfStyleBorderWidth = SettingsControl(
        "kiwishelf.border_width",
        "Border width"
    )
    let kiwishelfStyleHighlightWidth = SettingsControl(
        "kiwishelf.highlight_width",
        "Highlight width"
    )
    let kiwishelfStyleItemGap = SettingsControl(
        "kiwishelf.item_gap",
        "Item gap"
    )
    let kiwishelfStyleGlyphSizeAuto = SettingsControl(
        "kiwishelf.glyph_size.auto",
        "Auto glyph size"
    )
    let kiwishelfStyleGlyphSize = SettingsControl(
        "kiwishelf.glyph_size",
        "Glyph size"
    )
    let kiwishelfStyleFontSizeAuto = SettingsControl(
        "kiwishelf.font_size.auto",
        "Auto font size"
    )
    let kiwishelfStyleFontSize = SettingsControl(
        "kiwishelf.font_size",
        "Font size"
    )
    let kiwishelfStyleFontFamily = SettingsControl(
        "kiwishelf.font_family",
        "Font"
    )
    let kiwishelfStyleFontWeight = SettingsControl(
        "kiwishelf.font_weight",
        "Font weight"
    )
    let kiwishelfStyleIconSource = SettingsControl(
        "kiwishelf.icon_source.label",
        "App glyph style"
    )
    let kiwishelfStyleOrder = SettingsControl(
        "kiwishelf.order.label",
        "Order"
    )
    let kiwishelfStyleMinimum = SettingsControl(
        "kiwishelf.minimum",
        "Space Bar minimum"
    )
}

/// Space Bar ▸ Fine-tuning rows (#2507), keyed on their census
/// label keys, in `BarsRowOrder.spaceBarTuning`'s order.
struct SpaceBarTuningControls: Sendable {
    let frontAppTitleCap = SettingsControl(
        "space_bar.front_app_title_cap",
        "Front app title length"
    )
    let glyphSpan = SettingsControl(
        "space_bar.glyph_span",
        "Glyphs per Space"
    )
    let glyphGap = SettingsControl(
        "space_bar.glyph_gap",
        "Glyph gap"
    )
    let springDelay = SettingsControl(
        "space_bar.spring_delay",
        "Spring delay"
    )
}

/// KiwiShelf ▸ Each bar and Pocket rows, grouped by bar (#3612),
/// in `BarsRowOrder.kiwishelfEach`' order: each bar's Show, its
/// Position and its Per screen or area drawer, whose two children
/// anchor one drawer.
struct KiwiShelfEachControls: Sendable {
    let spaceBarShow = SettingsControl(
        "kiwishelf.show.space_bar",
        "Space Bar"
    )
    let kiwishelfSpaceBarEdge = SettingsControl(
        "kiwishelf.edge.space_bar",
        "Space Bar"
    )
    let kiwishelfSpaceBarScreenEdges = SettingsControl(
        "kiwishelf.edge.per_screen.space_bar",
        "Per screen or area"
    )
    let kiwishelfSpaceBarScreenShows = SettingsControl(
        "kiwishelf.show.per_screen.space_bar",
        "Space Bar: Show per screen"
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
    let kiwishelfAppBarEdge = SettingsControl(
        "kiwishelf.edge.app_bar",
        "App Bar"
    )
    let kiwishelfAppBarScreenEdges = SettingsControl(
        "kiwishelf.edge.per_screen.app_bar",
        "Per screen or area"
    )
    let kiwishelfAppBarScreenShows = SettingsControl(
        "kiwishelf.show.per_screen.app_bar",
        "App Bar: Show per screen"
    )
    let pocketShow = SettingsControl(
        "kiwishelf.show.pocket",
        "Pocket"
    )
    let pocketDragReveal = SettingsControl(
        "kiwishelf.show.pocket_drag",
        "Show the Pocket while dragging a window"
    )
    let kiwishelfPocketEdge = SettingsControl(
        "kiwishelf.edge.pocket",
        "Pocket"
    )
    let kiwishelfPocketScreenEdges = SettingsControl(
        "kiwishelf.edge.per_screen.pocket",
        "Per screen or area"
    )
    let kiwishelfPocketPosition = SettingsControl(
        "kiwishelf.pocket_position",
        "Pocket position"
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
