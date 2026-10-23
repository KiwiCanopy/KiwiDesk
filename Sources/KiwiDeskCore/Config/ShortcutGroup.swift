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

    /// The built-in group `name` spells, matched on the token alone,
    /// case and surrounding spaces aside; nil names a group of its
    /// own.
    public static func builtIn(_ name: String) -> ShortcutGroup? {
        ShortcutGroup(
            rawValue: name.trimmingCharacters(in: .whitespaces).lowercased()
        )
    }

    /// The groups `bindings` make of their own, in the order a
    /// binding first names each — built-in tokens and empty names
    /// left out.
    public static func custom(in bindings: [KeyBinding]) -> [String] {
        var seen: Set<String> = []
        var names: [String] = []
        for binding in bindings {
            let name = binding.group.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, builtIn(name) == nil,
                seen.insert(name).inserted
            else { continue }
            names.append(name)
        }
        return names
    }
}
