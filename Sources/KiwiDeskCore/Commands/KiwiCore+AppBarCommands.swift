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
        guard
            let args = field == "edge"
                ? screenResolvedEdgeArgs(args) : args
        else { return .fail(Self.unknownScreen) }
        switch AppBarCommandSetting.parse(field: field, args: args)
        {
        case .success(let setting):
            setting.apply(to: &tiler.settings.appBarStyle)
            if case .screenEdge = setting {
                tiler.settings.appBarStyle.collapseScreenEdges(
                    among: connectedScreens
                )
            }
            return .ok()
        case .failure(let error):
            return .fail(error.message)
        }
    }

    /// `space_bar.set_*` (#293) — the Space Bar is global-only,
    /// so this is the whole command surface (no override route).
    func spaceBarCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard command.hasPrefix("space_bar.set_") else {
            return .fail("unknown command: \(command)")
        }
        let field = String(
            command.dropFirst("space_bar.set_".count)
        )
        guard
            let args = field == "edge"
                ? screenResolvedEdgeArgs(args) : args
        else { return .fail(Self.unknownScreen) }
        switch SpaceBarCommandSetting.parse(
            field: field,
            args: args
        ) {
        case .success(let setting):
            setting.apply(to: &tiler.settings.spaceBarStyle)
            if case .screenEdge = setting {
                tiler.settings.spaceBarStyle.collapseScreenEdges(
                    among: connectedScreens
                )
            }
            return .ok()
        case .failure(let error):
            return .fail(error.message)
        }
    }

    /// `kiwishelf.set_*` (#1517) — the shelf both bars sit on.
    func kiwishelfCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard command.hasPrefix("kiwishelf.set_") else {
            return .fail("unknown command: \(command)")
        }
        let field = String(
            command.dropFirst("kiwishelf.set_".count)
        )
        switch KiwiShelfCommandSetting.parse(
            field: field,
            args: args
        ) {
        case .success(let setting):
            setting.apply(to: &tiler.settings.kiwishelf)
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
        if let global = AppBarStyle.layoutFixedKeys.first(where: {
            $0.key.stringValue == field
        })?.value {
            return .fail("the App Bar's \(field) is global: \(global)")
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
