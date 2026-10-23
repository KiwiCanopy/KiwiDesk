import Foundation

/// What a binding says of itself (#2544 ▸ Ruling): a description
/// shown in place of its Lua, the group it is listed in, and the SF
/// Symbol its row wears — each empty for none. Read from
/// `KiwiDesk.bind`'s and `define_layer`'s option tables. The one
/// home of the three fields: `KeyBinding.meta` reads and writes them
/// whole, and every comparison or copy goes through it
/// (`ShortcutMetaCarryTests` ▸ `metaIsTheOneHome`).
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

    /// The symbol a row wears where it names an SF Symbol; nil where
    /// it names none, or one that is not — the Config Issue's
    /// predicate and the row's, one answer (#2544).
    @MainActor public var usableSymbol: String? {
        symbol.isEmpty || !KiwiCore.iconIsSymbol(symbol) ? nil : symbol
    }

    /// Names a symbol that is no SF Symbol: a Config Issue.
    @MainActor var namesUnknownSymbol: Bool {
        !symbol.isEmpty && usableSymbol == nil
    }
}

/// A Lua-owned chord whose body was not read back (#2482), with what
/// it says of itself (#2544). Never a `KeyBinding`, so no save path
/// can turn one into a no-op row.
public struct UnreadChord: Equatable, Sendable {
    public let chord: String
    public let meta: KeyBindingMeta

    public init(chord: String, meta: KeyBindingMeta = .none) {
        self.chord = chord
        self.meta = meta
    }
}
