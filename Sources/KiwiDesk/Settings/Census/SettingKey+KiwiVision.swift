/// KiwiVision rows (#2103): the app-wide `kiwivision` group
/// (#1741's store), written at once. Each greys where `init.lua`
/// owns the config; Blur also greys with its card under Reduce
/// transparency, which the dim is exempt from.
enum KiwiVisionKey: String, CaseIterable, Hashable {
    case dim = "appWide.visionDim"
    case blur = "appWide.visionBlur"
    case appearance = "appWide.visionAppearance"
    case clearWallpaper = "appWide.visionClearWallpaper"
    case clearApp = "appWide.visionClearApp"
    case neverDimmed = "appWide.visionNeverDimmed"
    /// Lua-only until the lens page lands (#2103 v3 PR 7).
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
        case .appearance:
            return .row(
                .kiwiVision,
                .kiwiVisionAppearance,
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
            return .luaOnly
        }
    }

    var text: SettingRowText {
        switch self {
        case .dim:
            return .text("kiwivision.dim")
        case .blur:
            return .text("kiwivision.blur", help: "kiwivision.blur.help")
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
        case .neverDimmed:
            return .text(
                "kiwivision.never_dimmed",
                help: "kiwivision.never_dimmed.help"
            )
        case .lenses:
            return .none
        }
    }
}
