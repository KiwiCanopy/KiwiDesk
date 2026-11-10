import Foundation

/// The Lua mark, `</>` (#2544 ▸ Ruling): what a binding of the
/// user's own wears without a symbol of its own, and everywhere else
/// KiwiDesk marks Lua — the Shortcuts side, its resolve guard and
/// Settings ▸ Lua's editor tab.
enum LuaMark {
    static let symbol = "chevron.left.forwardslash.chevron.right"
}

/// What a key that opens more keys wears without a symbol of its
/// own (#3162 ▸ Ruling amendment): the Key sequences card's popover
/// and the hint panel's branch rows.
enum BranchMark {
    static let symbol = "folder"
}
