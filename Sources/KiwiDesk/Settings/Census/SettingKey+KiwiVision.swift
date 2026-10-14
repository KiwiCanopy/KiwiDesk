/// KiwiVision rows (#2103): the app-wide `kiwivision` group
/// (#1741's store), written at once. Each greys where `init.lua`
/// owns the config; Blur also greys with its card under Reduce
/// transparency, which the dim is exempt from.
enum KiwiVisionKey: String, CaseIterable, Hashable {
    case dim = "appWide.visionDim"
    case blur = "appWide.visionBlur"
    case appearance = "appWide.visionAppearance"
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
        }
    }
}
