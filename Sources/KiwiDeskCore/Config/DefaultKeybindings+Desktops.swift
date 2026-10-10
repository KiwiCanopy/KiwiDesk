import Foundation

/// The Desktop tier of the seeded ladder: `⌃⌥⇧⌘` + digit goes to
/// that macOS Desktop. Focus only — moving a window to a Desktop
/// stays an offer (#1125). `⇧` here lifts the ladder to the native
/// tier rather than acting on the window; the ruling is
/// `docs/design-decisions.md` ▸ *The Desktop tier is seeded*.
extension DefaultKeybindings {
    /// The row that goes to Desktop `number`, or nil past the ten
    /// digits.
    public static func desktopRow(_ number: Int) -> KeyBinding? {
        guard (1...digitCapacity).contains(number) else { return nil }
        let digit = number == digitCapacity ? "0" : String(number)
        return KeyBinding(
            combo: "control+option+shift+command+\(digit)",
            lua: "KiwiDesk.focus_desktop(\(number))",
            kind: .navigation,
            label: "Go to Desktop \(number)"
        )
    }

    /// Rows for the Desktops in `desktops` numbered above `mark`
    /// that no row in `existing` already goes to and whose chord
    /// is free. Additive, like `digitTopUp`: a Desktop at or
    /// below the mark was offered before, so a row the user
    /// deleted stays deleted.
    public static func desktopTopUp(
        existing: [KeyBinding],
        desktops: [Int],
        above mark: Int
    ) -> [KeyBinding] {
        var taken = Set(existing.compactMap { KeyCombo.parse($0.combo) })
        let bound = Set(existing.map(\.lua))
        var rows: [KeyBinding] = []
        for number in Set(desktops).sorted() where number > mark {
            guard let row = desktopRow(number),
                !bound.contains(row.lua),
                let combo = KeyCombo.parse(row.combo),
                taken.insert(combo).inserted
            else { continue }
            rows.append(row)
        }
        return rows
    }
}
