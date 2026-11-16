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

    /// The verdict over `value`, a preference read by domain (nil
    /// is the global domain) and key. An absent or unreadable key
    /// reads as macOS's shipped default — Dock shown at the bottom,
    /// menu bar shown — so a failed read leaves the edge free.
    /// `_HIHideMenuBar` covers "Always" and "On Desktop Only"; the
    /// bars stand down in full screen (#670), so "In Full Screen
    /// Only" owns no edge a bar rests on (measured on the issue).
    static func read(
        _ value: (_ domain: String?, _ key: String) -> Any?
    ) -> MacEdges {
        let hides = flag(value("com.apple.dock", "autohide"))
        let place = value("com.apple.dock", "orientation") as? String
        let edge: AppBarEdge =
            switch place {
            case "left": .left
            case "right": .right
            default: .bottom
            }
        return MacEdges(
            dock: hides ? edge : nil,
            menuBar: flag(value(nil, "_HIHideMenuBar"))
        )
    }

    private static func flag(_ value: Any?) -> Bool {
        (value as? NSNumber)?.boolValue ?? false
    }

    /// The live read: cfprefsd pushes another process's write to
    /// this one, so no change notification is needed and nothing
    /// is cached (about 1 µs a read, measured 2026-11-15, #3349).
    static func live() -> MacEdges {
        read { domain, key in
            CFPreferencesCopyAppValue(
                key as CFString,
                (domain as CFString?) ?? kCFPreferencesAnyApplication
            )
        }
    }
}
