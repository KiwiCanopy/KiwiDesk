import Foundation

extension KiwiShelf {
    /// What KiwiDesk's menu bar item shows (#3532). `auto` is the
    /// Space Bar's stand-in (#1413): the logo while a screen's
    /// Space Bar is drawn at rest, its Space where it is not. The
    /// other three ignore the Space Bar's Show. Under every choice
    /// a non-default layer's glyph leads (#1169).
    public enum MenuBarIcon: String, Sendable, Codable, CaseIterable {
        case auto
        case logo
        /// Each screen's current Space: its icon, else its name.
        case identifier
        /// The symbol of the layout each current Space uses.
        case layout
    }
}
