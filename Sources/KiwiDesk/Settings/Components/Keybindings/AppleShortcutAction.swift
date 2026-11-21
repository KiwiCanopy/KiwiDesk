import Combine
import KiwiDeskCore
import SwiftUI

/// A binding that runs one of the user's Apple Shortcuts (#3526).
/// The row is derived from the binding's `lua`, the way an app key's
/// is (`AppShortcutAction`), never a persisted field — so there is
/// no `KeyBinding` shape to migrate. It is filed as an `.application`
/// row, the picker family that launches something.
enum AppleShortcutAction {
    /// The mark a Shortcut row and its picker entry wear: Core's,
    /// which its pill wears too.
    static let symbol = AppleShortcuts.symbol

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

    /// Whether `binding` runs an Apple Shortcut: every reader asks
    /// here, never `kind` alone, since the row is filed as an app's.
    static func isRow(_ binding: KeyBinding) -> Bool {
        name(from: binding.lua) != nil
    }

    /// An app row of the Open applications card: `.application`
    /// that runs no Apple Shortcut.
    static func isAppRow(_ binding: KeyBinding) -> Bool {
        binding.kind == .application && !isRow(binding)
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

/// The user's Apple Shortcuts as Core last read them (#3526): the
/// GUI's one copy of `AppleShortcuts.names`, kept by Core's
/// `onNamesChanged`, so the pickers and the rows agree with what a
/// press decides by.
@MainActor
final class AppleShortcutLibrary: ObservableObject {
    static let shared = AppleShortcutLibrary()

    /// Sorted names, nil until a read finished.
    @Published private(set) var names: [String]?

    /// Mirrors `core`'s list from now on; called once at launch.
    func attach(_ core: KiwiCore) {
        if let names = core.appleShortcuts.names {
            take(Array(names).sorted())
        }
        core.appleShortcuts.onNamesChanged = { [weak self] list in
            self?.take(list)
        }
    }

    /// Asks `core` for a fresh read; its answer lands here too.
    func reload(from core: KiwiCore) async {
        if let list = await core.appleShortcuts.list() { take(list) }
    }

    /// Whether `name` is known to be gone; false while unread.
    func isMissing(_ name: String) -> Bool {
        guard let names else { return false }
        return !names.contains(name)
    }

    private func take(_ list: [String]) {
        if list != names { names = list }
    }

    #if DEBUG
        /// Tests only.
        func setNamesForTesting(_ list: [String]?) {
            names = list
        }
    #endif
}
