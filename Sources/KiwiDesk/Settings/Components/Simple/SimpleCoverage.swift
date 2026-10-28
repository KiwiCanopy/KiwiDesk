import KiwiDeskCore

/// Which save-pill rows Simple draws a control for (#2737 ruling
/// 12): the one answer `SettingsModel.jump(to:)` reads to keep a row
/// on Simple or land it on Advanced. Read off the row, not its key
/// alone: a shortcut row is Simple's only on the default layer and
/// only for the families its cards list, and a pin only where
/// Simple draws the Screen menu.
@MainActor enum SimpleCoverage {
    static func draws(
        _ row: SettingsDiffRow,
        in model: SettingsModel
    ) -> Bool {
        switch row.key {
        case .spaces(.spacesName), .spaces(.spaceModes):
            return true
        case .screens(.spacePins), .screens(.mainSpaces):
            return model.offersScreenMenu
        case .shortcuts(.layers):
            return drawsBinding(row.revert, in: model)
        default:
            return false
        }
    }

    /// A default-layer binding of a family Simple's cards draw:
    /// KiwiHub's keys (`ShortcutsRowOrder.kiwiHubAtRest`) or an
    /// Open applications row.
    private static func drawsBinding(
        _ revert: SettingsRowRevert,
        in model: SettingsModel
    ) -> Bool {
        guard case .binding(let layer, let lua) = revert,
            layer == KeyLayer.defaultName
        else { return false }
        let expander = ShortcutsFamilyRows.ofDraft(model, layer: layer)
        let kiwiHub = ShortcutsRowOrder.kiwiHubAtRest
            .compactMap(expander.rows(for:)).joined()
        if kiwiHub.contains(where: { $0.runs(lua) }) { return true }
        return [model.config, model.cleanConfig]
            .compactMap { $0.layers.first(where: \.isDefault) }
            .flatMap(\.bindings)
            .contains { $0.lua == lua && $0.kind == .application }
    }
}
