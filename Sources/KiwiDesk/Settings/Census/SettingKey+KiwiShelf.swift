/// The shelf both bars sit on (`KiwiShelf`, #1517) slice of the
/// census. Its card also draws the Show rows behind the Show
/// master, whose keys stay with the value they write
/// (`spaceBarVisibility`, the two layout App Bar visibilities,
/// `pocketVisibility`).

enum KiwiShelfKey: String, CaseIterable, Hashable {
    /// The Show master: every bar's visibility and the Pocket's
    /// (#761, #2978), which it writes through `masterWrites`.
    case visibility = "settings.spaceBarStyle.visibility (master)"
    /// The Position master: both bars' edges (#1731), which it
    /// writes through `masterWrites`.
    case edge = "settings.spaceBarStyle.edge (master)"
    case spaceBarEdge = "settings.spaceBarStyle.edge"
    case appBarEdge = "settings.appBarStyle.edge"
    /// Each bar's per-screen edges (#1948): a row per screen in
    /// that bar's Per screen drawer.
    case spaceBarScreenEdge = "settings.spaceBarStyle.edgeOverride[screen]"
    case appBarScreenEdge = "settings.appBarStyle.edgeOverride[screen]"
    case thickness = "settings.kiwishelf.thickness"
    case alignment = "settings.kiwishelf.alignment"
    case order = "settings.kiwishelf.order"
    case minimum = "settings.kiwishelf.minimum"
    case background = "settings.kiwishelf.backgroundStyle"
    case backgroundFit = "settings.kiwishelf.backgroundFit"
    case cornerRoundness = "settings.kiwishelf.cornerRoundness"
    case border = "settings.kiwishelf.border"
    case borderWidth = "settings.kiwishelf.borderWidth"
    case highlightWidth = "settings.kiwishelf.highlightWidth"
    case itemGap = "settings.kiwishelf.itemGap"
    case glyphSizeAuto = "settings.kiwishelf.glyphSize (auto)"
    case glyphSize = "settings.kiwishelf.glyphSize"
    case fontSizeAuto = "settings.kiwishelf.fontSize (auto)"
    case fontSize = "settings.kiwishelf.fontSize"
    case fontFamily = "settings.kiwishelf.fontFamily"
    case fontWeight = "settings.kiwishelf.fontWeight"
    case outerMargin = "settings.kiwishelf.outerMargin"
    case innerMargin = "settings.kiwishelf.innerMargin"
    case liquidGlass = "settings.kiwishelf.liquidGlass"
    case iconSource = "settings.kiwishelf.iconSource"
    case dimFactor = "settings.kiwishelf.dimFactor"
    case revealTimeout = "settings.kiwishelf.revealTimeout"
    case fillFade = "settings.kiwishelf.fillFade"
    case tintHubAndPlates = "settings.kiwishelf.tintHubAndPlates"
    case readingContrast = "settings.kiwishelf.readingContrast"
    case revealStyle = "settings.kiwishelf.revealStyle"
    case pocketEdge = "settings.kiwishelf.pocketEdge"
    case pocketPosition = "settings.kiwishelf.pocketPosition"
    /// The pocket's Show (#2978), behind the Show master's drawer.
    case pocketVisibility = "settings.kiwishelf.pocketVisibility"
    case maximizedVisibility = "settings.kiwishelf.maximizedVisibility"
    case fillColor = "settings.kiwishelf.fillColor"
    case borderColor = "settings.kiwishelf.borderColor"
    case itemColor = "settings.kiwishelf.itemColor"
    case activeItemColor = "settings.kiwishelf.activeItemColor"
    case highlightColor = "settings.kiwishelf.highlightColor"
    case hoverFillColor = "settings.kiwishelf.hoverFillColor"
    case hoverItemColor = "settings.kiwishelf.hoverItemColor"
    case groupBadgeColor = "settings.kiwishelf.groupBadgeColor"
    case groupBadgeTextColor = "settings.kiwishelf.groupBadgeTextColor"
    /// An Auto bar's resting handle (#3357); empty is Automatic.
    case handleColor = "settings.kiwishelf.handleColor"
}

extension KiwiShelfKey {
    var placement: SettingPlacement {
        switch self {
        case .edge, .visibility:
            // A master acknowledges divergence through its `?`
            // and carries no gate (`GapsBordersGates.acknowledged`).
            return .row(.bars, .kiwishelf, .atRest)
        case .thickness, .alignment, .pocketEdge, .pocketPosition:
            return .row(.bars, .kiwishelf, .atRest)
        case .spaceBarEdge, .appBarEdge, .spaceBarScreenEdge,
            .appBarScreenEdge, .pocketVisibility:
            return .row(.bars, .kiwishelf, .showMore)
        case .background, .cornerRoundness, .border, .highlightWidth,
            .itemGap, .glyphSizeAuto, .fontSizeAuto, .fontFamily,
            .outerMargin, .innerMargin, .iconSource, .order, .minimum:
            return .row(.bars, .kiwishelf, .showMore)
        case .maximizedVisibility:
            // Greyed while nothing could reveal (#3346 ▸ 9).
            return .row(
                .layoutDefaults,
                .maximize,
                .atRest,
                gate: .runtime(.nothingRevealsMaximized)
            )
        case .revealStyle:
            // In the Show group under Each bar, greyed while no bar
            // hides (owner ruling, 2026-10-21).
            return .row(
                .bars,
                .kiwishelf,
                .atRest,
                gate: .runtime(.noBarHides)
            )
        case .backgroundFit:
            return .row(
                .bars,
                .kiwishelf,
                .showMore,
                gate: .setting(.kiwishelf(.background))
            )
        case .fontWeight:
            // Greyed while the family is not installed.
            return .row(
                .bars,
                .kiwishelf,
                .showMore,
                gate: .setting(.kiwishelf(.fontFamily))
            )
        case .fontSize:
            return .row(
                .bars,
                .kiwishelf,
                .showMore,
                gate: .setting(.kiwishelf(.fontSizeAuto))
            )
        case .glyphSize:
            return .row(
                .bars,
                .kiwishelf,
                .showMore,
                gate: .setting(.kiwishelf(.glyphSizeAuto))
            )
        case .borderWidth:
            return .row(
                .bars,
                .kiwishelf,
                .showMore,
                gate: .setting(.kiwishelf(.border))
            )
        case .liquidGlass:
            // Written by the one Liquid Glass row (#1307).
            return .luaOnly
        case .dimFactor:
            return .luaOnly
        case .revealTimeout:
            // Lua/CLI until its Settings row lands (#761).
            return .luaOnly
        case .readingContrast:
            // A power-user floor: GUI curates, Lua is open (#2569).
            return .luaOnly
        case .fillFade:
            // The Liquid Glass group, under its switch (#2569):
            // hidden below macOS 26 as the switch is; greyed while
            // it is off or the Fill has no colour, by wiring.
            return .row(
                .coloursAndMotion,
                .glass,
                .atRest,
                gate: .runtime(.liquidGlassUnavailable)
            )
        case .tintHubAndPlates:
            // The Fill tints the panels over their material too
            // (#2569 ▸ amendment): shown on every macOS, live under
            // Reduce transparency, greyed while the Fill has no
            // colour, by wiring.
            return .row(
                .coloursAndMotion,
                .glass,
                .atRest,
                exemptFromContainerGate: true
            )
        case .activeItemColor, .highlightColor, .hoverFillColor:
            // The accent's bar half (#1857).
            return .row(.coloursAndMotion, .accent, .showMore)
        case .fillColor:
            // Drawn in the Liquid Glass group, above the rows it
            // greys, outside the Colors drawer (#2593).
            return .row(.coloursAndMotion, .kiwishelf, .atRest)
        case .itemColor, .hoverItemColor, .groupBadgeColor,
            .groupBadgeTextColor, .handleColor:
            return .row(.coloursAndMotion, .kiwishelf, .showMore)
        case .borderColor:
            // Inert while the border is off (#1679).
            return .row(
                .coloursAndMotion,
                .kiwishelf,
                .showMore,
                gate: .setting(.kiwishelf(.border))
            )
        }
    }
}
