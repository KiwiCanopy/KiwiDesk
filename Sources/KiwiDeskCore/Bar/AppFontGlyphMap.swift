import Foundation

/// App name to ligature table, read from the vendored font's
/// own `APPM` data map (`Resources/AppFont/UPSTREAM.md`) so the
/// names can never drift from the glyphs the font carries.
///
/// A name ending in `*` is a prefix match upstream
/// (`"Adobe Photoshop*"` names "Adobe Photoshop 2026"); an exact
/// name wins over any prefix, and a longer prefix over a
/// shorter one. Matching is case-sensitive, as upstream's is.
struct AppFontGlyphMap: Sendable, Equatable {
    struct Prefix: Sendable, Equatable {
        let prefix: String
        let ligature: String
    }

    private(set) var exact: [String: String] = [:]
    /// Longest first, so the first hit is the most specific.
    private(set) var prefixes: [Prefix] = []

    /// Builds the table from `name -> ligature` pairs, reading a
    /// trailing `*` as a prefix. Empty names and ligatures are
    /// dropped: a bad drop must not reserve blank glyph slots.
    init(_ pairs: [(name: String, ligature: String)]) {
        for (name, ligature) in pairs where !ligature.isEmpty {
            if name.hasSuffix("*") {
                let prefix = String(name.dropLast())
                guard !prefix.isEmpty else { continue }
                prefixes.append(Prefix(prefix: prefix, ligature: ligature))
            } else if !name.isEmpty {
                exact[name] = ligature
            }
        }
        prefixes.sort { $0.prefix.count > $1.prefix.count }
    }

    /// Test convenience: one ligature per name.
    init(_ map: [String: String]) {
        self.init(map.map { (name: $0.key, ligature: $0.value) })
    }

    /// The ligature for `name`, or nil when no entry covers it.
    func ligature(for name: String) -> String? {
        if let hit = exact[name] { return hit }
        return prefixes.first { name.hasPrefix($0.prefix) }?.ligature
    }

    /// Every ligature the table can answer.
    var ligatures: Set<String> {
        Set(exact.values).union(prefixes.map(\.ligature))
    }

    /// Loads the bundled font's table. Nil is a build defect
    /// (the shipped-resource test fails); at runtime it only
    /// degrades to image rendering, never a crash.
    static func loadBundled() -> AppFontGlyphMap? {
        guard
            let url = Bundle.kiwiDeskCore.url(
                forResource: AppFont.fontName,
                withExtension: "ttf",
                subdirectory: "AppFont"
            ),
            let font = try? Data(contentsOf: url)
        else { return nil }
        return load(fontData: font)
    }

    /// Decodes the `APPM` payload of `fontData` (schema
    /// version 1); nil for any other shape.
    static func load(fontData: Data) -> AppFontGlyphMap? {
        guard
            let payload = AppFontMetaTable.dataMap(
                "APPM",
                in: fontData
            ),
            let decoded = try? JSONDecoder().decode(
                Payload.self,
                from: payload
            ),
            decoded.version == 1
        else { return nil }
        return AppFontGlyphMap(
            decoded.icons.flatMap { icon in
                icon.appNames.map {
                    (name: $0, ligature: icon.ligature)
                }
            }
        )
    }

    /// `{"version": 1, "release": …, "icons": [[ligature,
    /// codepoint, appNames | null], …]}`; utility icons carry
    /// null names and map nothing.
    private struct Payload: Decodable {
        let version: Int
        let icons: [Icon]
    }

    private struct Icon: Decodable {
        let ligature: String
        let appNames: [String]

        init(from decoder: Decoder) throws {
            var row = try decoder.unkeyedContainer()
            ligature = try row.decode(String.self)
            _ = try row.decode(Int.self)
            appNames = try row.decodeIfPresent([String].self) ?? []
        }
    }
}
