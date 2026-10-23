import Foundation
import KiwiDeskCore

/// A built-in shortcut group's title in the user's language
/// (#2544): the one place the GUI names it, read by KiwiHub's bands
/// and Settings' shortcut group field alike.
extension ShortcutGroup {
    @MainActor var title: String {
        switch self {
        case .focus: L("shortcuts.section.focus", "Focus")
        case .moveWindows:
            L("shortcuts.section.move_windows", "Move windows")
        case .layout: L("shortcuts.section.layout", "Layout")
        case .sizeFloat: L("shortcuts.section.size_float", "Size & float")
        case .kiwivision: L("destination.kiwivision", "KiwiVision")
        case .kiwishelf: L("bars.switch.kiwishelf", "KiwiShelf")
        case .apps: L("shortcuts.panel.apps", "Apps")
        }
    }
}

/// How Settings' shortcut group field shows a stored `group` and
/// stores what the user typed (#2544 ▸ Ruling): a built-in group
/// reads as its title and is stored as its token; a group of the
/// user's own is its name as written.
struct ShortcutGroupNaming {
    let titles: [ShortcutGroup: String]

    @MainActor static var current: ShortcutGroupNaming {
        ShortcutGroupNaming(
            titles: Dictionary(
                uniqueKeysWithValues: ShortcutGroup.allCases.map {
                    ($0, $0.title)
                }
            )
        )
    }

    /// The field's text for a stored value.
    func shown(_ stored: String) -> String {
        switch ShortcutGroup.filing(stored) {
        case .none: return ""
        case .builtIn(let group): return titles[group] ?? group.rawValue
        case .own(let name): return name
        }
    }

    /// The stored value for typed text: a built-in group's title or
    /// token, case aside, files into that group.
    func stored(_ typed: String) -> String {
        let name = typed.trimmingCharacters(in: .whitespaces)
        if let group = titles.first(where: {
            $0.value.compare(name, options: .caseInsensitive)
                == .orderedSame
        })?.key {
            return group.rawValue
        }
        switch ShortcutGroup.filing(name) {
        case .none: return ""
        case .builtIn(let group): return group.rawValue
        case .own(let own): return own
        }
    }
}
