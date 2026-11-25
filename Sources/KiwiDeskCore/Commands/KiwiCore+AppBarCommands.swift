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
        // A layout's own field parses here too, so only the
        // style's own fields dispatch (#3618).
        guard
            AppBarStyle.CodingKeys.allCases.contains(where: {
                BarStyleKeys.setterField(of: $0.stringValue) == field
            })
        else { return .fail("unknown bar setting: \(field)") }
        let calls: [[JSONValue]]
        switch screenResolvedBarArgs(field: field, args) {
        case .success(let resolved): calls = resolved
        case .failure(let error): return .fail(error.message)
        }
        for given in calls {
            switch AppBarCommandSetting.parse(field: field, args: given)
            {
            case .success(let setting):
                if case .screenEdge(let edge, let screen) = setting {
                    tiler.settings.appBarStyle.setEdge(
                        edge,
                        on: screen,
                        among: liveScreenEdgeScope
                    )
                } else {
                    setting.apply(to: &tiler.settings.appBarStyle)
                }
            case .failure(let error):
                return .fail(error.message)
            }
        }
        return .ok()
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
        let calls: [[JSONValue]]
        switch screenResolvedBarArgs(field: field, args) {
        case .success(let resolved): calls = resolved
        case .failure(let error): return .fail(error.message)
        }
        for given in calls {
            switch SpaceBarCommandSetting.parse(field: field, args: given)
            {
            case .success(let setting):
                if case .screenEdge(let edge, let screen) = setting {
                    tiler.settings.spaceBarStyle.setEdge(
                        edge,
                        on: screen,
                        among: liveScreenEdgeScope
                    )
                } else {
                    setting.apply(to: &tiler.settings.spaceBarStyle)
                }
            case .failure(let error):
                return .fail(error.message)
            }
        }
        return .ok()
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
        let calls: [[JSONValue]]
        switch screenResolvedEdgeArgs(
            field: field,
            screenField: "pocket_edge",
            args
        ) {
        case .success(let resolved): calls = resolved
        case .failure(let error): return .fail(error.message)
        }
        for given in calls {
            switch KiwiShelfCommandSetting.parse(field: field, args: given)
            {
            case .success(let setting):
                if case .pocketScreenEdge(let edge, let screen) = setting {
                    tiler.settings.kiwishelf.pocketEdges.setEdge(
                        edge,
                        on: screen,
                        among: liveScreenEdgeScope
                    )
                } else {
                    setting.apply(to: &tiler.settings.kiwishelf)
                }
            case .failure(let error):
                return .fail(error.message)
            }
        }
        return .ok()
    }

    /// Applies a layout's `*.set_app_bar_<field>` override.
    /// `visibility` is the layout's own concrete value (#761), or
    /// with a screen that screen's or area's (#3618); every other
    /// field writes an override of the global style.
    func applyBarOverride(
        field: String,
        _ args: [JSONValue],
        into mode: LayoutMode
    ) -> CommandResponse {
        guard let layout = TilingSettings.appBarPath(for: mode) else {
            return .fail("unknown command: \(mode.rawValue).set_app_bar_")
        }
        if let global = AppBarStyle.layoutFixedKeys.first(where: {
            $0.key.stringValue == field
        })?.value {
            return .fail("the App Bar's \(field) is global: \(global)")
        }
        let calls: [[JSONValue]]
        switch screenResolvedBarArgs(field: field, args) {
        case .success(let resolved): calls = resolved
        case .failure(let error): return .fail(error.message)
        }
        // A physical screen names each of its areas (#3517).
        for given in calls {
            switch AppBarCommandSetting.parse(field: field, args: given)
            {
            case .success(.visibility(let value)):
                // A layout's own Show clears its areas' (ruling 32).
                tiler.settings.setAppBarVisibility(value, in: mode)
            case .success(let setting):
                setting.apply(to: &tiler.settings[keyPath: layout])
            case .failure(let error):
                return .fail(error.message)
            }
        }
        return .ok()
    }
}
