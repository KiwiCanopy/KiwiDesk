import Foundation

/// Stamps the handle colour a bundled palette paints (#3377) into a
/// stored colour set that wears that palette in every other key and
/// leaves the handle Automatic (#3409, `HandleStampMigrationTests`):
/// matching is strict, so without it an upgraded Kiwi (Default) or
/// Glass reads as no palette. A set that differs elsewhere was
/// custom and stays custom. Reached by PATH: a profile's
/// `settings`, `gui.json`'s shared `look.colors`, a saved look's
/// `colors` in `looks.json`, and a bundle's copies of all three.
/// A palette library and a look's credit (`origin`, `based_on`)
/// are never stamped.
extension ConfigMigration {
    /// The formats this step introduced, per shape, spelled as
    /// history: a set stamped later with an Automatic handle is the
    /// user's.
    static let handleStampProfileFormat = 41
    static let handleStampGuiFormat = 28
    static let handleStampLookFormat = 6
    static let handleStampBundleFormat = 52

    static let handleStampPath = "kiwishelf.handle_color"
    static let handleStampKey = "handle_color"
    /// The colour each bundled palette paints the handle from.
    static let handleStampSourcePath = "kiwishelf.active_item_color"
    static let handleStampColorsKey = "colors"
    static let handleStampLookKey = "look"
    static let handleStampProfilesKey = "profiles"
    static let handleStampLooksKey = "looks"
    static let handleStampConfigKey = "config"

    @Sendable
    static func migratingHandleStamp(_ data: Data) -> Data? {
        guard belowHandleStampFloor(data) else { return nil }
        return surgicallyApplying(
            data,
            rewriting: withHandleStamped,
            editing: handleStampText
        )
    }

    private static func belowHandleStampFloor(_ data: Data) -> Bool {
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else { return false }
        let format = root["format"] as? Int ?? 0
        switch shape(of: root) {
        case .bundle: return format < handleStampBundleFormat
        case .profile: return format < handleStampProfileFormat
        case .gui: return format < handleStampGuiFormat
        case .looks: return format < handleStampLookFormat
        case .palettes: return false
        }
    }

    /// The paths, per shape. An exported look file classifies as
    /// a `gui.json` root and carries its body under `look`, so the
    /// gui arm reaches it through `lookExportSteps` too.
    static func withHandleStamped(_ node: Any) -> (Any, Bool) {
        guard var root = node as? [String: Any] else { return (node, false) }
        var changed = false
        func edit(_ key: String, _ body: ([String: Any]) -> [String: Any]?) {
            guard let object = root[key] as? [String: Any],
                let out = body(object)
            else { return }
            root[key] = out
            changed = true
        }
        func editEach(
            _ key: String,
            _ body: ([String: Any]) -> [String: Any]?
        ) {
            guard var list = root[key] as? [[String: Any]] else { return }
            var did = false
            for index in list.indices {
                guard let out = body(list[index]) else { continue }
                list[index] = out
                did = true
            }
            guard did else { return }
            root[key] = list
            changed = true
        }
        switch shape(of: root) {
        case .profile:
            edit(glassSettingsKey, stampedSettings)
        case .gui:
            edit(handleStampLookKey, stampedLook)
        case .looks:
            editEach(handleStampLooksKey, stampedLook)
        case .bundle:
            edit(handleStampConfigKey) { config in
                guard let look = config[handleStampLookKey] as? [String: Any],
                    let out = stampedLook(look)
                else { return nil }
                var config = config
                config[handleStampLookKey] = out
                return config
            }
            editEach(handleStampProfilesKey) { profile in
                guard
                    let settings = profile[glassSettingsKey]
                        as? [String: Any],
                    let out = stampedSettings(settings)
                else { return nil }
                var profile = profile
                profile[glassSettingsKey] = out
                return profile
            }
            editEach(handleStampLooksKey, stampedLook)
        case .palettes:
            break
        }
        return (root, changed)
    }

    /// A `TilingSettings` object, its colours read by their dotted
    /// path; nil where nothing is stamped.
    static func stampedSettings(
        _ settings: [String: Any]
    ) -> [String: Any]? {
        var colors: [String: String] = [:]
        for path in handleStampPalettes[0].colors.keys {
            let parts = path.split(separator: ".").map(String.init)
            guard parts.count == 2,
                let group = settings[parts[0]] as? [String: Any],
                let hex = group[parts[1]] as? String
            else { continue }
            colors[path] = hex
        }
        guard let handle = handleStamp(for: colors),
            var shelf = settings[shelfKey] as? [String: Any]
        else { return nil }
        shelf[handleStampKey] = handle
        var out = settings
        out[shelfKey] = shelf
        return out
    }

    /// A look body or a saved look: its flat `colors` map.
    static func stampedLook(_ look: [String: Any]) -> [String: Any]? {
        guard var colors = look[handleStampColorsKey] as? [String: String],
            let handle = handleStamp(for: colors)
        else { return nil }
        colors[handleStampPath] = handle
        var out = look
        out[handleStampColorsKey] = colors
        return out
    }

    /// The handle the first frozen palette `colors` wears paints,
    /// where its stored handle is absent or Automatic. An absent
    /// path reads the shipped colour, as the decoder and
    /// `ShelfLook.admitted` complete it — save the accent the handle
    /// is painted from: a set that never stored it chose no palette.
    static func handleStamp(for colors: [String: String]) -> String? {
        guard (colors[handleStampPath] ?? "").isEmpty,
            colors[handleStampSourcePath] != nil
        else { return nil }
        let shipped = handleStampPalettes[0].colors
        for palette in handleStampPalettes {
            guard let handle = palette.colors[handleStampPath],
                !handle.isEmpty
            else { continue }
            let fits = palette.colors.allSatisfy { path, hex in
                path == handleStampPath
                    || ColorPalette.sameColor(
                        hex,
                        colors[path] ?? shipped[path] ?? ""
                    )
            }
            if fits { return handle }
        }
        return nil
    }

    /// The text with each stamp written in place, where the walk
    /// writes one handle value: an Automatic handle's `""` replaced,
    /// or, in a file that names no handle, the value inserted after
    /// each `kiwishelf` and `colors` opener. Trade: the edit reaches
    /// every such member and opener, a credit's included, so a file
    /// the walk stamps only in part fails the envelope's compare and
    /// is re-serialized by the walk instead.
    static func handleStampText(_ text: String) -> Data? {
        guard
            let root = try? JSONSerialization.jsonObject(
                with: Data(text.utf8)
            ),
            let handle = loneHandleStamp(in: root)
        else { return nil }
        let keys = [handleStampKey, handleStampPath]
        let named = keys.contains { text.contains("\"\($0)\"") }
        var out = text
        if named {
            for key in keys {
                let name = NSRegularExpression.escapedPattern(for: key)
                out = out.replacingOccurrences(
                    of: "(\"\(name)\"\\s*:\\s*)\"\"",
                    with: "$1\"\(handle)\"",
                    options: .regularExpression
                )
            }
        } else {
            let openers = [
                (handleStampKey, shelfKey),
                (handleStampPath, handleStampColorsKey),
            ]
            for (key, opener) in openers {
                out = insertingAfterEach(
                    "\"\(key)\":\"\(handle)\"",
                    pattern: "(\"\(opener)\"\\s*:\\s*\\{)(\\s*\\})?",
                    in: out
                )
            }
        }
        return out == text ? nil : Data(out.utf8)
    }

    /// The one handle value the walk writes, or nil where it
    /// writes none or several.
    private static func loneHandleStamp(in root: Any) -> String? {
        let (stamped, changed) = withHandleStamped(root)
        guard changed,
            let data = try? JSONSerialization.data(withJSONObject: stamped),
            let text = String(data: data, encoding: .utf8)
        else { return nil }
        let values = Set(
            captures(
                "\"(?:\(handleStampKey)|kiwishelf\\.handle_color)\""
                    + "\\s*:\\s*\"([^\"]*)\"",
                in: text
            )
        )
        return values.count == 1 ? values.first : nil
    }
}
