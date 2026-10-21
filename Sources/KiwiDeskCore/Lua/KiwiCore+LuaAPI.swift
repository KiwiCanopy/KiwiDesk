import Foundation

extension JSONValue {
    /// Bridges command results back into Lua.
    var luaValue: LuaValue {
        switch self {
        case .null:
            return .none
        case .bool(let b):
            return .bool(b)
        case .number(let n):
            return .number(n)
        case .string(let s):
            return .string(s)
        case .array(let items):
            return .array(items.map(\.luaValue))
        case .object(let dict):
            return .table(dict.mapValues(\.luaValue))
        }
    }
}

/// Registers the KiwiDesk Lua API.
///
/// Main commands live on the global `KiwiDesk` table; layout
/// sub-APIs live on `stack`, `bsp`, `scroll`, and `grid`
/// tables.
extension KiwiCore {
    func registerLuaAPI(on lua: LuaInterpreter) {
        for entry in APIReference.commands {
            register(
                entry.command,
                as: entry.lua,
                in: "KiwiDesk",
                lua
            )
        }
        for (table, functions) in APIReference.namespaces {
            for function in functions {
                register(
                    "\(table).\(function)",
                    as: function,
                    in: table,
                    lua
                )
            }
        }
        registerEventAPI(on: lua)
        registerKeybindingAPI(on: lua)
        registerUIAPI(on: lua)
        registerExecAPI(on: lua)
        installTypoGuards(on: lua)
    }

    /// UI-bridge verbs that cross Core → GUI (#330). A Lua-only
    /// one carries no dispatcher `CommandResponse` — it raises a
    /// `@MainActor` hook the app wires to a window — so, like
    /// `bind`/`on`, it lives outside `APIReference.commands` and is
    /// listed in `luaOnly` for `help()`. `kiwihub.show` is the
    /// dispatched one: it parses a side, so it answers, and the CLI
    /// reaches it (#2265). The VM never holds the UI ref.
    ///
    /// **The family is four hand-mirrored lists** — a
    /// `UIBridgeHooks` field, a `register` call here (or a
    /// namespace entry), an `APIReference.luaOnly` entry and the
    /// `AppDelegate` wiring — and a verb missing any one of them is
    /// a silent no-op rather than a build error. `UIBridgeParityTests`
    /// derives the roster from the struct's own fields and holds
    /// the other three against it (`parity-tests.md`: past two
    /// mirrors, ship the forget-proof test).
    private func registerUIAPI(on lua: LuaInterpreter) {
        lua.register("open_settings") { [weak self] _ in
            self?.uiBridge.onOpenSettings()
            return .none
        }
    }

    /// `KiwiDesk.bind`, `define_layer`, and `switch_layer`.
    private func registerKeybindingAPI(
        on lua: LuaInterpreter
    ) {
        lua.register("bind") { [weak self] args in
            guard let self,
                let text = args.first?.stringValue,
                let combo = KeyCombo.parse(text),
                case .functionRef(let ref) =
                    args.dropFirst().first ?? .none
            else {
                self?.onLog(
                    "bind(): expected combo and function"
                )
                return .none
            }
            self.keys.bind(combo, ref: ref)
            return .none
        }
        lua.register("define_layer") { [weak self] args in
            guard let self,
                let name = args.first?.stringValue,
                case .table(let table) =
                    args.dropFirst().first ?? .none
            else {
                self?.onLog(
                    "define_layer(): expected name and table"
                )
                return .none
            }
            var bindings: [KeyCombo: Int32] = [:]
            for (key, value) in table {
                guard let combo = KeyCombo.parse(key),
                    case .functionRef(let ref) = value
                else {
                    self.onLog(
                        "define_layer('\(name)'): bad key "
                            + "'\(key)'"
                    )
                    continue
                }
                bindings[combo] = ref
            }
            let icon = Self.layerIcon(
                from: args.dropFirst(2).first
            )
            self.keys.defineLayer(
                name,
                bindings: bindings,
                icon: icon
            )
            return .none
        }
        lua.register("switch_layer") { [weak self] args in
            guard let name = args.first?.stringValue else {
                self?.onLog(
                    "switch_layer(): expected layer name"
                )
                return .none
            }
            self?.keys.switchLayer(name)
            return .none
        }
    }

    /// Reads `{ icon = "..." }` from `define_layer`'s optional
    /// third argument.
    private static func layerIcon(
        from value: LuaValue?
    ) -> String? {
        guard case .table(let opts)? = value else {
            return nil
        }
        return opts["icon"]?.stringValue
    }

    private func register(
        _ command: String,
        as luaName: String,
        in table: String,
        _ lua: LuaInterpreter
    ) {
        lua.register(luaName, in: table) { [weak self] args in
            guard let self else { return .none }
            let response = self.execute(
                command,
                args: args.map(\.jsonValue)
            )
            if let error = response.error {
                self.onLog("\(command): \(error)")
            }
            return response.data?.luaValue ?? .none
        }
    }

    /// `KiwiDesk.on(event, callback)`.
    private func registerEventAPI(on lua: LuaInterpreter) {
        lua.register("on") { [weak self] args in
            guard let self,
                let name = args.first?.stringValue,
                let event = KiwiNotification(rawValue: name),
                case .functionRef(let ref) =
                    args.dropFirst().first ?? .none
            else {
                self?.onLog(
                    "on(): expected event name and function"
                )
                return .none
            }
            self.bus.on(event, ref: ref)
            return .none
        }
    }
}

/// The UI-bridge verbs' `@MainActor` GUI hooks, bundled (the
/// `OpenOrFocusSeams` shape) so `KiwiCore.swift` carries one
/// line for the family rather than one block per verb. Each
/// verb raises its hook and returns nothing to Lua; the GUI
/// (`AppDelegate`) wires both, weakly, and each is a no-op
/// until wired.
///
/// **A field's name IS its verb name**, lower-snake with the
/// `on` dropped (`onOpenSettings` ↔ `open_settings`) and a leading
/// namespace read as its table (`onKiwihubShow` ↔ `kiwihub.show`),
/// which is what lets `UIBridgeParityTests` derive the roster by
/// reflection rather than re-listing it. `kiwihub.show` toggles a
/// panel side, while `open_settings` opens-or-raises a window.
public struct UIBridgeHooks {
    /// `KiwiDesk.open_settings()` (#678 item 18): the bindable
    /// "Open Settings" action, seeded on ⌃⌥, (#1381). Opens or
    /// raises, never toggles — a key that closed Settings
    /// would discard the draft state the save pill narrates.
    public var onOpenSettings: @MainActor () -> Void = {}

    /// `kiwihub.show(side)` (#2265): opens KiwiHub on `side`,
    /// switches it there, or closes it when that side is up.
    public var onKiwihubShow: @MainActor (KiwiHubSide) -> Void = {
        _ in
    }

    /// `restore_setup` (#2517) replaced the setup under an open
    /// Settings window, which re-reads it as its own Restore… does.
    public var onSetupRestored: @MainActor () -> Void = {}

    public init() {}
}
