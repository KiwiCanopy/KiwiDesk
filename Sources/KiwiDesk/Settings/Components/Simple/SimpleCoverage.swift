import KiwiDeskCore

/// Which save-pill rows Simple draws a control for (#2737 ruling
/// 12): the one answer `SettingsModel.jump(to:)` reads to keep a row
/// on Simple or land it on Advanced. Read off the row, not its key
/// alone: a shortcut row is Simple's only for an Open applications
/// key on the default layer, and a pin only where Simple draws the
/// Screen menu.
@MainActor enum SimpleCoverage {
    static func draws(
        _ row: SettingsDiffRow,
        in model: SettingsModel
    ) -> Bool {
        draws(row, screenMenu: model.offersScreenMenu) {
            drawsBinding($0, in: model)
        }
    }

    /// The answer over its two model reads, so both screen counts
    /// are assertable.
    static func draws(
        _ row: SettingsDiffRow,
        screenMenu: Bool,
        binding: (SettingsRowRevert) -> Bool
    ) -> Bool {
        switch row.key {
        case .spaces(.spacesName), .spaces(.spaceModes):
            return true
        case .screens(.spacePins), .screens(.mainSpaces):
            return screenMenu
        case .shortcuts(.layers):
            return binding(row.revert)
        // The areas a look paints (`LookKeys`): the Look line wrote
        // them, so their rows stay with it (ruling 12). Read by
        // area, so a row of these areas made in Advanced stays too.
        case .kiwishelf, .spaceBar, .appBar, .borders, .gaps, .colours:
            return true
        default:
            return false
        }
    }

    /// A default-layer Open applications row; KiwiHub's keys are
    /// shown on Simple, not edited, so their rows land on Advanced.
    private static func drawsBinding(
        _ revert: SettingsRowRevert,
        in model: SettingsModel
    ) -> Bool {
        guard case .binding(let layer, let lua) = revert,
            layer == KeyLayer.defaultName
        else { return false }
        return [model.config, model.cleanConfig]
            .compactMap { $0.layers.first(where: \.isDefault) }
            .flatMap(\.bindings)
            .contains { $0.lua == lua && $0.kind == .application }
    }
}
