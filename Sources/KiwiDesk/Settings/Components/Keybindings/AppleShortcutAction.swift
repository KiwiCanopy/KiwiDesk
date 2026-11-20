import Combine
import KiwiDeskCore
import SwiftUI

/// A binding that runs one of the user's Apple Shortcuts (#3526).
/// The row is derived from the binding's `lua`, the way an app key's
/// is (`AppShortcutAction`), never a persisted field — so there is
/// no `KeyBinding` shape to migrate. It is filed as an `.application`
/// row, the picker family that launches something.
enum AppleShortcutAction {
    /// The mark a Shortcut row, its picker entry and its pill wear.
    static let symbol = "square.2.layers.3d"

    private static let prefix = "KiwiDesk.run_shortcut(\""
    private static let suffix = "\")"

    /// The Lua running `name`, quoted as a Lua string.
    static func command(_ name: String) -> String {
        var quoted = ""
        for character in name {
            switch character {
            case "\\": quoted += "\\\\"
            case "\"": quoted += "\\\""
            case "\n": quoted += "\\n"
            case "\r": quoted += "\\r"
            default: quoted.append(character)
            }
        }
        return prefix + quoted + suffix
    }

    /// The shortcut `lua` runs, nil unless it is exactly a call
    /// `command(_:)` writes.
    static func name(from lua: String) -> String? {
        guard lua.hasPrefix(prefix), lua.hasSuffix(suffix),
            lua.count > prefix.count + suffix.count
        else { return nil }
        let inner = lua.dropFirst(prefix.count).dropLast(suffix.count)
        var name = ""
        var escaping = false
        for character in inner {
            if escaping {
                switch character {
                case "\\", "\"": name.append(character)
                case "n": name.append("\n")
                case "r": name.append("\r")
                default: return nil
                }
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else if character == "\"" {
                return nil
            } else {
                name.append(character)
            }
        }
        return escaping ? nil : name
    }

    /// The binding a pick writes.
    static func binding(
        _ name: String,
        combo: String = ""
    ) -> KeyBinding {
        KeyBinding(
            combo: combo,
            lua: command(name),
            kind: .application,
            label: name
        )
    }

    /// The gesture action a pick writes.
    static func action(_ name: String) -> LuaAction {
        LuaAction(
            lua: command(name),
            kind: .application,
            meta: KeyBindingMeta(desc: name)
        )
    }

    /// Why a picker says a chord set in the Shortcuts app is unseen:
    /// macOS lists those chords nowhere KiwiDesk can read (#3526).
    @MainActor static var conflictBlindSpot: String {
        L(
            "shortcuts.apple_shortcut.blind_spot",
            "A keyboard shortcut set in the Shortcuts app is not "
                + "checked for conflicts. If KiwiDesk binds the same "
                + "keys, KiwiDesk's binding wins and the shortcut "
                + "does not run."
        )
    }
}

/// The user's Apple Shortcuts as Core last read them (#3526): one
/// list the pickers and the rows share, so a row knows whether its
/// shortcut still exists. Core reads the list off the main actor.
@MainActor
final class AppleShortcutLibrary: ObservableObject {
    static let shared = AppleShortcutLibrary()

    /// Sorted names, nil until a read finished or where it failed.
    @Published private(set) var names: [String]?

    /// Re-reads the list through `core`.
    func reload(from core: KiwiCore) async {
        if let list = await core.appleShortcuts.list() {
            if list != names { names = list }
        }
    }

    /// Whether `name` is known to be gone; false while unread.
    func isMissing(_ name: String) -> Bool {
        guard let names else { return false }
        return !names.contains(name)
    }

    #if DEBUG
        /// Tests only.
        func setNamesForTesting(_ list: [String]?) {
            names = list
        }
    #endif
}
