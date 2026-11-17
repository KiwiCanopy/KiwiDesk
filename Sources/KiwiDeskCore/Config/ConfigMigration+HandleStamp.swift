import Foundation

/// Stamps the handle colour a bundled palette paints (#3377) into a
/// stored colour set wearing that palette in every other key with
/// its handle Automatic (#3409, `HandleStampMigrationTests`), by
/// PATH; a palette library and a look's credit are never stamped.
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

    /// An exported look file's body, under `look`, ungated: the
    /// `lookExportSteps` entry lifting to `handleStampLookFormat` is
    /// its floor, since the file is never rewritten.
    @Sendable
    static func migratingHandleStampLookExport(_ data: Data) -> Data? {
        surgicallyApplying(
            data,
            rewriting: { node in
                guard var root = node as? [String: Any],
                    let look = root[handleStampLookKey] as? [String: Any],
                    let out = stampedLook(look)
                else { return (node, false) }
                root[handleStampLookKey] = out
                return (root, true)
            },
            editing: { _ in nil }
        )
    }

    /// The paths, per shape.
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
        for path in handleStampShipped.keys {
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

    /// The frozen default palette: every colour path 5.0 stores.
    static var handleStampShipped: [String: String] {
        handleStampPalettes.first { $0.name == "Kiwi (Default)" }?.colors
            ?? [:]
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
        let shipped = handleStampShipped
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

    /// The walk's one handle value written into the text: over each
    /// Automatic `""`, or after each `kiwishelf` and `colors` opener
    /// where the file names no handle; the envelope refuses an
    /// over-edit.
    static func handleStampText(_ text: String) -> Data? {
        guard
            let root = try? JSONSerialization.jsonObject(
                with: Data(text.utf8)
            ),
            let handle = loneHandleStamp(in: root)
        else { return nil }
        let keys = handleStampKeys
        let named = keys.contains { text.contains("\"\($0)\"") }
        var out = text
        if named {
            for key in keys {
                out = out.replacingOccurrences(
                    of: "(\"\(pattern(key))\"\\s*:\\s*)\"\"",
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

    private static var handleStampKeys: [String] {
        [handleStampKey, handleStampPath]
    }

    private static func pattern(_ key: String) -> String {
        NSRegularExpression.escapedPattern(for: key)
    }

    /// The one handle value the walk writes, or nil where it
    /// writes none or several.
    private static func loneHandleStamp(in root: Any) -> String? {
        let (stamped, changed) = withHandleStamped(root)
        guard changed,
            let data = try? JSONSerialization.data(withJSONObject: stamped),
            let text = String(data: data, encoding: .utf8)
        else { return nil }
        let names = handleStampKeys.map(pattern).joined(separator: "|")
        let values = Set(
            captures(
                "\"(?:\(names))\"\\s*:\\s*\"([^\"]*)\"",
                in: text
            )
        )
        return values.count == 1 ? values.first : nil
    }
}
