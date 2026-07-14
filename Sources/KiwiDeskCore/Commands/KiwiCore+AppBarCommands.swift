import Foundation

/// The indicator bar's command surface: the global `app_bar.set_*`
/// look, and the shared machinery each layout's `*.set_app_bar_*`
/// overrides route through.
extension KiwiCore {
    /// `app_bar.set_*` — the global look every layout's bar inherits
    /// unless it overrides the same field.
    func barCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard command.hasPrefix("app_bar.set_") else {
            return .fail("unknown command: \(command)")
        }
        let field = String(
            command.dropFirst("app_bar.set_".count)
        )
        switch AppBarCommandSetting.parse(field: field, args: args)
        {
        case .success(let setting):
            setting.apply(to: &tiler.settings.appBarStyle)
            return .ok()
        case .failure(let error):
            return .fail(error.message)
        }
    }

    /// Applies a layout's `*.set_app_bar_<field>` override.
    /// `enabled` is the layout's own concrete toggle; every
    /// other field writes an override of the global style.
    func applyBarOverride(
        field: String,
        _ args: [JSONValue],
        into bar: inout LayoutAppBar
    ) -> CommandResponse {
        if field == "enabled" {
            guard let enabled = args.first?.boolValue else {
                return .fail("expected boolean")
            }
            bar.enabled = enabled
            return .ok()
        }
        switch AppBarCommandSetting.parse(field: field, args: args)
        {
        case .success(let setting):
            setting.apply(to: &bar)
            return .ok()
        case .failure(let error):
            return .fail(error.message)
        }
    }
}
