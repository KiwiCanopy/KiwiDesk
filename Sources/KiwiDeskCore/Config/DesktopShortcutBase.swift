import Foundation

/// The modifiers the Go to Desktop rows sit on (#1870):
/// `gui.json`'s `desktop_shortcut_base`, app-wide and drafted with
/// the layers so a Save or a Revert moves the rows and the base
/// together. Only the Hyper move offer changes it, and its reverse
/// resets it; the top-up writes a new Desktop's row on it. Strict:
/// a spelling this build does not know fails the decode, so a
/// renamed case owes a `ConfigMigration` step (AGENTS.md §5).
public enum DesktopShortcutBase: String, Codable, Sendable, CaseIterable {
    /// `⌃⌥⇧⌘` + digit, the seeded tier
    /// (`docs/design-decisions.md` ▸ *The Desktop tier is seeded*).
    case standard = "control+option+shift+command"
    /// `✦` + digit, once the move offer was accepted.
    case hyper

    /// The chord this base gives `key`, in the stored spelling.
    public func combo(_ key: String) -> String { "\(rawValue)+\(key)" }
}
