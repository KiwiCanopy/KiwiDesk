import Foundation

/// What a binding says of itself (#2544 ▸ Ruling): a description
/// shown in place of its Lua, the group it is listed in, and the SF
/// Symbol its row wears — each empty for none. Read from
/// `KiwiDesk.bind`'s and `define_layer`'s option tables, and carried
/// onto the `KeyBinding` a Lua-owned load recovers.
public struct KeyBindingMeta: Equatable, Sendable {
    public var desc = ""
    public var group = ""
    public var symbol = ""

    public static let none = KeyBindingMeta()

    public init(desc: String = "", group: String = "", symbol: String = "") {
        self.desc = desc
        self.group = group
        self.symbol = symbol
    }

    /// The fields a Lua option table spells (`desc`, `group`,
    /// `symbol`); other keys and non-string values are ignored.
    init(options: [String: LuaValue]) {
        desc = options["desc"]?.stringValue ?? ""
        group = options["group"]?.stringValue ?? ""
        symbol = options["symbol"]?.stringValue ?? ""
    }

    /// Lays the fields onto `binding`.
    func applied(to binding: KeyBinding) -> KeyBinding {
        var binding = binding
        binding.desc = desc
        binding.group = group
        binding.symbol = symbol
        return binding
    }
}
