import ApplicationServices
import Foundation

/// The two presses behind `new_window` and `close_window` (#1518):
/// an app's File ▸ New Window and a window's close button. Each
/// is a blocking AX walk of another app, so it runs off the main
/// actor (`WindowActionSeams`), bounded by the process-global
/// messaging timeout.
enum AXWindowActions {
    /// One File-menu row as AX reports it.
    struct MenuItem: Equatable, Sendable {
        var title: String
        /// `AXMenuItemCmdChar`, nil where the row has no key.
        var key: String?
        /// `AXMenuItemCmdModifiers`: 0 is ⌘ alone, 1 is ⇧⌘.
        var modifiers: Int?
        var enabled: Bool
    }

    /// A word for "window" as a menu title spells it, in every
    /// language macOS ships — Apple's own (AppKit's "Close Window",
    /// every locale), stemmed where the word inflects, plus the two
    /// other apps use (ウィンドウ, Chrome's 창). A menu's language is
    /// the app's, not KiwiDesk's, so all of them are asked at once.
    /// Matching data, not copy.
    static let windowWords = [
        "window",
        "fenster",
        "fenetre",
        "ventana",
        "finestra",
        "janela",
        "venster",
        "fönster",
        "vindu",
        "ikkun",
        "okn",
        "prozor",
        "ablak",
        "pencere",
        "fereastr",
        "jendela",
        "tetingkap",
        "cửa sổ",
        "παράθυρ",
        "ウインドウ",
        "ウィンドウ",
        "윈도우",
        "창",
        "окн",
        "вікн",
        "窗口",
        "視窗",
        "نافذ",
        "חלון",
        "विंडो",
        "หน้าต่าง",
    ]

    /// The New Window row: ⌘N, else ⇧⌘N, whose title names a
    /// window. Menu identifiers are nib-generated and titles are
    /// the app's own language, so the key and the word together
    /// are the identity (device probe on the issue, 2026-09-30:
    /// Antigravity's ⌘N is New Text File, Claude's New Session).
    /// A disabled match still answers, so the caller can refuse.
    static func newWindowItem(in items: [MenuItem]) -> Int? {
        let named = items.indices.filter { index in
            let item = items[index]
            return item.key?.uppercased() == "N"
                && windowWords.contains {
                    item.title.range(
                        of: $0,
                        options: [.caseInsensitive, .diacriticInsensitive]
                    ) != nil
                }
        }
        return named.first { items[$0].modifiers == 0 }
            ?? named.first { items[$0].modifiers == 1 }
    }

    /// Presses the app's New Window row. False where the app has
    /// none, or it is disabled. The File menu is the one after
    /// the app menu, which the HIG fixes.
    static func pressNewWindow(pid: pid_t) -> Bool {
        let app = AXHelper.appElement(pid: pid)
        guard
            let bar = AXHelper.attribute(
                app,
                kAXMenuBarAttribute,
                as: AXUIElement.self
            ),
            let file = children(of: bar).dropFirst(2).first,
            let menu = children(of: file).first
        else { return false }
        let elements = children(of: menu)
        let items = elements.map(menuItem)
        guard let index = newWindowItem(in: items),
            items[index].enabled
        else { return false }
        return AXUIElementPerformAction(
            elements[index],
            kAXPressAction as CFString
        ) == .success
    }

    /// Presses the window's close button. False where it has
    /// none, or it is disabled. An unreadable enabled flag reads
    /// as enabled here and on a menu row alike: the press is the
    /// test. The app answers unsaved work its
    /// own way, as a click would.
    static func pressClose(_ window: AXUIElement) -> Bool {
        guard
            let button = AXHelper.attribute(
                window,
                kAXCloseButtonAttribute,
                as: AXUIElement.self
            ),
            AXHelper.attribute(
                button,
                kAXEnabledAttribute,
                as: Bool.self
            ) != false
        else { return false }
        return AXUIElementPerformAction(
            button,
            kAXPressAction as CFString
        ) == .success
    }

    private static func children(
        of element: AXUIElement
    ) -> [AXUIElement] {
        AXHelper.attribute(
            element,
            kAXChildrenAttribute,
            as: [AXUIElement].self
        ) ?? []
    }

    private static func menuItem(
        _ element: AXUIElement
    ) -> MenuItem {
        MenuItem(
            title: AXHelper.attribute(
                element,
                kAXTitleAttribute,
                as: String.self
            ) ?? "",
            key: AXHelper.attribute(
                element,
                "AXMenuItemCmdChar",
                as: String.self
            ),
            modifiers: AXHelper.attribute(
                element,
                "AXMenuItemCmdModifiers",
                as: Int.self
            ),
            enabled: AXHelper.attribute(
                element,
                kAXEnabledAttribute,
                as: Bool.self
            ) != false
        )
    }
}
