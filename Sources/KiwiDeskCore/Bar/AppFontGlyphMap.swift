import Foundation

/// Decodes vendored icon_map.json into app name to ligature map
/// (`Resources/AppFont/UPSTREAM.md`).
enum AppFontGlyphMap {
    struct Entry: Decodable {
        let iconName: String
        let appNames: [String]
    }

    /// Loads bundled icon map as a flat dictionary, or nil on failure.
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
