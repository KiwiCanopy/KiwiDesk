import Foundation

/// Discovers and decodes bundled locale JSON files
/// (`LocalizationManager`, #9).
public enum LocaleCatalog {
    /// Non-English locale codes on disk. The `!= "en"` filter is
    /// intentional: `en.json` is a build-time translator manifest
    /// (`scripts/extract-keys`), never loaded by the manager —
    /// English lives inline at call sites, and picking it in the
    /// language menu uses the inline source, distinct from
    /// "System default".
    static func availableLocales() -> [String] {
        guard
            let directory = Bundle.kiwiDeskCore.url(
                forResource: "Locales",
                withExtension: nil
            )
        else { return [] }
        let files =
            (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )) ?? []
        return
            files
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .filter { $0 != "en" }
            .sorted()
    }

    /// Loads and decodes locale dictionary (`SettingsCensusLabel`).
    public static func load(_ locale: String) -> [String: String] {
        guard
            let url = Bundle.kiwiDeskCore.url(
                forResource: locale,
                withExtension: "json",
                subdirectory: "Locales"
            ),
            let data = try? Data(contentsOf: url)
        else { return [:] }
        let decoded = try? JSONDecoder().decode(
            [String: String].self,
            from: data
        )
        return decoded ?? [:]
    }
}
