/// KiwiVision rows (#2103): the app-wide `kiwivision` group
/// (#1741's store), written at once. Each greys where `init.lua`
/// owns the config; Blur also greys with its card under Reduce
/// transparency, which the dim is exempt from.
enum KiwiVisionKey: String, CaseIterable, Hashable {
    case dim = "appWide.visionDim"
    case blur = "appWide.visionBlur"
    /// The leave fade's length and curve (#2417); the length is
    /// Lua-only, the speed preset's (#3238).
    case fadeDuration = "appWide.visionFadeDuration"
    case fadeCurve = "appWide.visionFadeCurve"
    case appearance = "appWide.visionAppearance"
    case clearWallpaper = "appWide.visionClearWallpaper"
    case clearApp = "appWide.visionClearApp"
    /// What the focused window fills while on (#3064).
    case maximize = "appWide.visionMaximize"
    case neverDimmed = "appWide.visionNeverDimmed"
    /// The lens page (#2103 ruling 29): one setting drawing a
    /// page per live lens, saved with the page's Save.
    case lenses = "appWide.visionLenses"
}

extension KiwiVisionKey {
    var placement: SettingPlacement {
        switch self {
        case .dim:
            return .row(
                .kiwiVision,
                .kiwiVisionLevels,
                .atRest,
                gate: .runtime(.luaOwnsConfig),
                exemptFromContainerGate: true
            )
        case .blur:
            return .row(
                .kiwiVision,
                .kiwiVisionLevels,
                .atRest,
                gate: .runtime(.luaOwnsConfig)
            )
        case .fadeDuration:
            // Lua-only: the speed preset is Settings' one pace
            // control (owner ruling, 2026-11-12, #3238).
            return .luaOnly
        // The dim still fades under Reduce transparency.
        case .fadeCurve:
            return .row(
                .kiwiVision,
                .kiwiVisionLevels,
                .atRest,
                gate: .runtime(.luaOwnsConfig),
                exemptFromContainerGate: true
            )
        case .appearance:
            return .row(
                .kiwiVision,
                .kiwiVisionAppearance,
                .atRest,
                gate: .runtime(.luaOwnsConfig)
            )
        case .maximize:
            return .row(
                .kiwiVision,
                .kiwiVisionMaximize,
                .atRest,
                gate: .runtime(.luaOwnsConfig)
            )
        case .clearWallpaper, .clearApp:
            return .row(
                .kiwiVision,
                .kiwiVisionClear,
                .atRest,
                gate: .runtime(.luaOwnsConfig)
            )
        case .neverDimmed:
            return .row(
                .kiwiVision,
                .kiwiVisionNeverDimmed,
                .atRest,
                gate: .runtime(.luaOwnsConfig)
            )
        case .lenses:
            return .row(
                .kiwiVision,
                .kiwiVisionLenses,
                .atRest,
                gate: .runtime(.luaOwnsConfig)
            )
        }
    }

    var text: SettingRowText {
        switch self {
        case .dim:
            return .text("kiwivision.dim")
        case .blur:
            return .text("kiwivision.blur", help: "kiwivision.blur.help")
        case .fadeDuration:
            return .none
        case .fadeCurve:
            return .text(
                "kiwivision.fade_curve",
                help: "kiwivision.fade_curve.help"
            )
        case .appearance:
            return .text(
                "kiwivision.appearance",
                help: "kiwivision.appearance.help"
            )
        case .clearWallpaper:
            return .text(
                "kiwivision.clear_wallpaper",
                help: "kiwivision.clear_wallpaper.help"
            )
        case .clearApp:
            return .text(
                "kiwivision.clear_app",
                help: "kiwivision.clear_app.help"
            )
        case .maximize:
            return .text(
                "kiwivision.maximize",
                help: "kiwivision.maximize.help"
            )
        case .neverDimmed:
            return .text(
                "kiwivision.never_dimmed",
                help: "kiwivision.never_dimmed.help"
            )
        case .lenses:
            return .text(
                "kiwivision.lenses",
                help: "kiwivision.lenses.help"
            )
        }
    }
}
