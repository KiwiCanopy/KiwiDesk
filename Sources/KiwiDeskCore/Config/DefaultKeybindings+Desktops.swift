import Foundation

/// The Desktop tier of the seeded ladder: `⌃⌥⇧⌘` + digit goes to
/// that macOS Desktop. Focus only — moving a window to a Desktop
/// stays an offer (#1125). `⇧` here lifts the ladder to the native
/// tier rather than acting on the window; the ruling is
/// `docs/design-decisions.md` ▸ *The Desktop tier is seeded*.
extension DefaultKeybindings {
    /// The seeded tier's row for Desktop `number`.
    public static func desktopRow(_ number: Int) -> KeyBinding? {
        desktopRow(number, base: .standard)
    }

    /// The row that goes to Desktop `number` on `base`, or nil past
    /// the ten digits.
    public static func desktopRow(
        _ number: Int,
        base: DesktopShortcutBase
    ) -> KeyBinding? {
        guard (1...digitCapacity).contains(number) else { return nil }
        let digit = number == digitCapacity ? "0" : String(number)
        return KeyBinding(
            combo: base.combo(digit),
            lua: "KiwiDesk.focus_desktop(\(number))",
            kind: .navigation,
            label: "Go to Desktop \(number)"
        )
    }

    /// Whether `row` goes to a Desktop — the seed's own spelling,
    /// derived from `desktopRow` rather than restated.
    public static func isDesktopRow(_ row: KeyBinding) -> Bool {
        guard let sample = desktopRow(1)?.lua,
            let open = sample.firstIndex(of: "(")
        else { return false }
        return row.lua.hasPrefix(sample[...open])
    }

    /// Rows on `base` for the Desktops in `desktops` numbered above
    /// `mark` that no row in `existing` already goes to and whose
    /// chord is free. Additive, like `digitTopUp`: a Desktop at or
    /// below the mark was offered before, so a row the user
    /// deleted stays deleted. A chord is free as registered, so a
    /// Hyper row is taken by its bare twin (#1870).
    public static func desktopTopUp(
        existing: [KeyBinding],
        desktops: [Int],
        above mark: Int,
        base: DesktopShortcutBase = .standard
    ) -> [KeyBinding] {
        var taken = Set(
            existing.compactMap { KeyCombo.parse($0.combo)?.registered }
        )
        let bound = Set(existing.map(\.lua))
        var rows: [KeyBinding] = []
        for number in Set(desktops).sorted() where number > mark {
            guard let row = desktopRow(number, base: base),
                !bound.contains(row.lua),
                let combo = KeyCombo.parse(row.combo),
                taken.insert(combo.registered).inserted
            else { continue }
            rows.append(row)
        }
        return rows
    }
}
