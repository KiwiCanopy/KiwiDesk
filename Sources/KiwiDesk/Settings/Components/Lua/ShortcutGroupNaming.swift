import Foundation
import KiwiDeskCore

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

    /// What the field stores when it commits `text` over `current`:
    /// unchanged text keeps the stored value, so an own group that
    /// shares a built-in title is never re-filed by a blur alone, and
    /// a New group left empty keeps the group it replaced.
    func committed(
        _ text: String,
        over current: String,
        startedNew: Bool = false
    ) -> String {
        if text == shown(current) { return current }
        if startedNew, stored(text).isEmpty { return current }
        return stored(text)
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
