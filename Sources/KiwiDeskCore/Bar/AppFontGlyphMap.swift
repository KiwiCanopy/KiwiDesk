import Foundation

/// Decodes the vendored `icon_map.json` (see
/// `Resources/AppFont/UPSTREAM.md`): an array of
/// `{iconName, appNames}` entries, expanded into a flat
/// display-name → ligature lookup. Upstream lists localized
/// app names as plain extra `appNames` members, so localized
/// lookups need no special handling here.
enum AppFontGlyphMap {
    struct Entry: Decodable {
        let iconName: String
        let appNames: [String]
    }

    /// The bundled map as a flat lookup, or nil when the
    /// resource is missing or corrupt — that is a build defect
    /// (the shipped-resource test fails); at runtime it only
    /// degrades to image rendering, never a crash.
    static func loadBundled() -> [String: String]? {
        guard
            let url = Bundle.kiwiDeskCore.url(
                forResource: "icon_map",
                withExtension: "json",
                subdirectory: "AppFont"
            )
        else { return nil }
        return load(from: url)
    }

    static func load(from url: URL) -> [String: String]? {
        guard
            let data = try? Data(contentsOf: url),
            let entries = try? JSONDecoder().decode(
                [Entry].self,
                from: data
            )
        else { return nil }
        var map: [String: String] = [:]
        // Skip degenerate entries (empty ligature or name):
        // a bad vendor drop must not reserve blank glyph
        // slots downstream.
        for entry in entries where !entry.iconName.isEmpty {
            for name in entry.appNames where !name.isEmpty {
                map[name] = entry.iconName
            }
        }
        return map
    }
}
