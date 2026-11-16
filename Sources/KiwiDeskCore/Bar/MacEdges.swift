import Foundation

/// The screen edges macOS auto-hides something on (#3349): the
/// Dock's edge while the Dock auto-hides, the top while the menu
/// bar does. A push there is macOS's, so an Auto bar's approach
/// hands over to it. The Dock's edge counts on every screen, since
/// with separate Spaces the Dock follows the pushed screen.
struct MacEdges: Equatable, Sendable {
    /// The auto-hidden Dock's edge; nil while the Dock stays shown.
    var dock: AppBarEdge?
    /// The menu bar hides on the Desktop.
    var menuBar = false

    /// Neither hides: every edge is KiwiDesk's.
    static let none = MacEdges()

    /// Whether macOS owns a push against `edge`.
    func owns(_ edge: AppBarEdge) -> Bool {
        edge == .top ? menuBar : edge == dock
    }

    /// The Dock's half over `value`, a preference read by domain
    /// and key: its edge while it auto-hides. An absent or
    /// unreadable key reads as macOS's shipped default — shown, at
    /// the bottom — so a failed read leaves the edge free.
    static func dock(
        _ value: (_ domain: String, _ key: String) -> Any?
    ) -> AppBarEdge? {
        let hides =
            (value("com.apple.dock", "autohide") as? NSNumber)?
            .boolValue ?? false
        guard hides else { return nil }
        switch value("com.apple.dock", "orientation") as? String {
        case "left": return .left
        case "right": return .right
        default: return .bottom
        }
    }

    /// The live read: the Dock's preferences, which cfprefsd pushes
    /// to this process so a read is fresh and needs no change
    /// notification (about 1 µs, measured 2026-11-15, #3349), and
    /// the menu bar through `GeometryUtils.menuBarAutoHides`, the one
    /// `_HIHideMenuBar` read — "Always" and "On Desktop Only"; the
    /// bars stand down in full screen (#670), so "In Full Screen
    /// Only" owns no edge a bar rests on.
    @MainActor static func live() -> MacEdges {
        MacEdges(
            dock: dock { domain, key in
                CFPreferencesCopyAppValue(
                    key as CFString,
                    domain as CFString
                )
            },
            menuBar: GeometryUtils.menuBarAutoHides
        )
    }
}
