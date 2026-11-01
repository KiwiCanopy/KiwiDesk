import Foundation

/// A per-app Pocket key row's stored Lua (#2612 ▸ 6): exactly
/// `KiwiDesk.pocket_app("<bundle id>")`, double-quoted, the bundle
/// id lowercased — an ordinary layer binding recognised by this
/// shape. The verb and the spelling are stored values: renaming
/// either owes a one-shot `ConfigMigration` step.
public enum PocketAppLuaArg {
    static let prefix = "KiwiDesk.pocket_app("

    /// The row's Lua for `bundleID`.
    public static func call(_ bundleID: String) -> String {
        "\(prefix)\(LuaLiteral.string(bundleID.lowercased())))"
    }

    /// The lowercased bundle id a row's Lua names, nil for any
    /// other shape.
    public static func bundleID(of lua: String) -> String? {
        guard lua.hasPrefix(prefix), lua.hasSuffix(")") else {
            return nil
        }
        let inner = String(lua.dropFirst(prefix.count).dropLast())
        return LuaLiteral.parseString(inner)?.lowercased()
    }
}
