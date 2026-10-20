import Foundation

/// The base KiwiDesk's default shortcuts sit on (#2460):
/// `gui.json`'s `shortcut_base`, app-wide and drafted with the
/// layers so a Save or a Revert moves the rows and the base
/// together. Every writer of a default row — the top-ups and
/// Restore Defaults — writes it through `rebased`. Strict: a
/// spelling this build does not know fails the decode, so a
/// renamed case owes a `ConfigMigration` step (AGENTS.md §5).
/// The ruling is `docs/design-decisions.md` ▸ *One switch puts
/// KiwiDesk's shortcuts on `⌃⌥` or on `✦`*.
public enum ShortcutBase: String, Codable, Sendable, CaseIterable {
    /// `⌃⌥`, the seed's own base.
    case standard = "control+option"
    /// `✦`, the Hyper key.
    case hyper

    /// `row` on this base: a chord the other base's mapping covers
    /// moves (`moved`), any other row is returned unchanged.
    public func rebased(_ row: KeyBinding) -> KeyBinding {
        guard let combo = KeyCombo.parse(row.combo),
            let target = Self.moved(combo, to: self)?.comboString()
        else { return row }
        var out = row
        out.combo = target
        return out
    }

    /// `combo` moved onto `base`, or nil where the mapping does
    /// not cover it. Onto `✦`: `⌃⌥` plus at most `⇧` and `⌘`,
    /// the base swapped and the rest kept — save the Desktop
    /// tier, `⌃⌥⇧⌘` + digit, which takes `✦⌥` + digit, since
    /// `✦⇧⌘3` is registered bare as macOS's screenshot `⇧⌘3`
    /// (#2460). Onto `⌃⌥`: the exact inverse, so only what the
    /// forward mapping produces moves back.
    public static func moved(
        _ combo: KeyCombo,
        to base: ShortcutBase
    ) -> KeyCombo? {
        switch base {
        case .hyper: toHyper(combo)
        case .standard: toStandard(combo)
        }
    }

    private static let standardModifiers: HotkeyModifiers = [
        .control, .option,
    ]
    private static let kept: HotkeyModifiers = [.shift, .command]

    private static func toHyper(_ combo: KeyCombo) -> KeyCombo? {
        let modifiers = combo.modifiers
        guard modifiers.isSuperset(of: standardModifiers),
            !modifiers.contains(.hyper)
        else { return nil }
        let rest = modifiers.subtracting(standardModifiers)
        guard kept.isSuperset(of: rest) else { return nil }
        let target: HotkeyModifiers =
            rest == kept && isDigit(combo)
            ? [.hyper, .option] : rest.union(.hyper)
        return KeyCombo(keyCode: combo.keyCode, modifiers: target)
    }

    private static func toStandard(_ combo: KeyCombo) -> KeyCombo? {
        guard combo.modifiers.contains(.hyper) else { return nil }
        let rest = combo.modifiers.subtracting(.hyper)
        let target: HotkeyModifiers
        if rest == .option, isDigit(combo) {
            target = standardModifiers.union(kept)
        } else if kept.isSuperset(of: rest) {
            target = standardModifiers.union(rest)
        } else {
            return nil
        }
        let back = KeyCombo(keyCode: combo.keyCode, modifiers: target)
        // `✦⇧⌘` + digit is no forward image: the Desktop tier
        // went to `✦⌥`, so a user's own `✦⇧⌘3` stays.
        return toHyper(back) == combo ? back : nil
    }

    private static func isDigit(_ combo: KeyCombo) -> Bool {
        KeyCombo.keyName(for: combo.keyCode).flatMap { Int($0) } != nil
    }
}
