import Foundation
import Testing

@testable import KiwiDesk

/// The 4f locale guard: every `L()` key the `SettingKey`
/// catalog names — label, caption, help — resolves to a
/// non-empty string in every shipped locale catalog. The
/// catalogs are read straight from the repo tree, so a key
/// renamed in a locale file (or a catalog case naming a key
/// that never existed) reds here before it ships as a raw key
/// on screen.
@Suite("SettingKey locale resolution")
struct SettingKeyLocaleTests {
    private static let localesDirectory = SourceScan.repoRoot(
        from: #filePath
    )
    .appendingPathComponent("Sources")
    .appendingPathComponent("KiwiDeskCore")
    .appendingPathComponent("Resources")
    .appendingPathComponent("Locales")

    private static func loadCatalogs() throws
        -> [String: [String: String]]
    {
        let files = try FileManager.default.contentsOfDirectory(
            at: localesDirectory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "json" }
        var catalogs: [String: [String: String]] = [:]
        for file in files {
            let data = try Data(contentsOf: file)
            let decoded = try JSONDecoder().decode(
                [String: String].self,
                from: data
            )
            catalogs[file.lastPathComponent] = decoded
        }
        return catalogs
    }

    /// Every text key in the catalog, with the case that owns
    /// it — labels plus the optional caption/help siblings.
    private static func textKeys() -> [(id: String, key: String)] {
        var out: [(String, String)] = []
        for key in SettingKey.allCases {
            let text = key.text
            if case .key(let label) = text.label {
                out.append((key.id, label))
            }
            if let caption = text.captionKey {
                out.append((key.id, caption))
            }
            if let help = text.helpKey {
                out.append((key.id, help))
            }
        }
        return out
    }

    /// A LABEL key must be renderable as-is: a key whose value
    /// carries a positional specifier is a per-instance
    /// template (`keybinding.focus_dir` = "Focus window %1$@")
    /// and its row must be `.dynamic` instead. Captions and
    /// help are prose and may interpolate.
    @Test func labelKeysCarryNoPositionalSpecifiers() throws {
        let catalogs = try Self.loadCatalogs()
        let en = try #require(catalogs["en.json"])
        var checked = 0
        for key in SettingKey.allCases {
            guard case .key(let label) = key.text.label else {
                continue
            }
            checked += 1
            #expect(
                en[label]?.contains("%1$") != true,
                "\(key.id): label \(label) is a template"
            )
        }
        #expect(checked > 100)
    }

    @Test func everyTextKeyResolvesInEveryLocale() throws {
        let catalogs = try Self.loadCatalogs()
        // Guard the fixture itself: an empty or misplaced
        // locale directory must red, not vacuously pass.
        #expect(catalogs["en.json"] != nil)
        #expect(catalogs.count > 1)
        let keys = Self.textKeys()
        #expect(!keys.isEmpty)
        for (locale, catalog) in catalogs {
            for (id, key) in keys {
                let value = catalog[key]
                #expect(
                    value?.isEmpty == false,
                    "\(locale): \(key) missing (row \(id))"
                )
            }
        }
    }
}
