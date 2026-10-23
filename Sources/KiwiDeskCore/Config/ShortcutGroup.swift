import Foundation

/// A built-in group of KiwiHub's Shortcuts side, named by the token
/// a binding's `group` spells (#2544 ▸ Ruling): a binding naming one
/// is listed in that group; any other name makes a group of its own.
/// Core names the group and the GUI titles it, so a built-in group
/// reads in the user's language and a user's own never is translated.
public enum ShortcutGroup: String, CaseIterable, Sendable {
    case focus
    case moveWindows = "move_windows"
    case layout
    case sizeFloat = "size_float"
    case kiwivision
    case kiwishelf
    case apps

    /// Where a binding's `group` files it: no group, a built-in one,
    /// or one of its own under its name as written, trimmed — the
    /// one classifier the panel and `shortcut.list_groups` read.
    public enum Filing: Equatable, Sendable {
        case none
        case builtIn(ShortcutGroup)
        case own(String)
    }

    /// Files `name`: a built-in token matches case and surrounding
    /// spaces aside.
    public static func filing(_ name: String) -> Filing {
        let name = name.trimmingCharacters(in: .whitespaces)
        if name.isEmpty { return .none }
        if let group = ShortcutGroup(rawValue: name.lowercased()) {
            return .builtIn(group)
        }
        return .own(name)
    }

    /// The groups `names` make of their own, in first-named order.
    public static func custom(in names: [String]) -> [String] {
        var seen: Set<String> = []
        return names.compactMap { name in
            guard case .own(let own) = filing(name),
                seen.insert(own).inserted
            else { return nil }
            return own
        }
    }
}
