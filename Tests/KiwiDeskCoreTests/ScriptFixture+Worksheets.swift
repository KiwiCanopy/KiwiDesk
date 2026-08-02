import Foundation

/// The worksheet half of `RepoShapedFixture` — the third tree a
/// repo-shaped fixture needs, since `scripts/extract-keys` writes
/// `missing_<locale>.json` outside every directory a target ships
/// from (`scripts/locale_paths.py` owns that path).
///
/// Split out of `ScriptFixture.swift` on the file-size ceiling
/// (AGENTS.md §2.1), not because it is a second concern: it is
/// the same `RepoShapedFixture`, and `.claude/rules/tests.md`'s
/// script-spawn exception covers it unchanged.
///
/// The accessors here deliberately say *worksheet* in their
/// names. An earlier draft had one `localeFileExists` decide by
/// filename which tree to inspect, which read identically at
/// every call site whichever answer it gave — so a later
/// `#expect(!fx.localeFileExists("missing_de.json"))` meaning
/// "not among the catalogs" would have passed by asking a
/// different directory entirely.
extension RepoShapedFixture {
    /// Where `scripts/extract-keys` leaves a worksheet and
    /// `scripts/merge-keys` reads it from: `<root>/locale-
    /// worksheets`, and `/site` under `--site`.
    var worksheets: URL {
        root.appendingPathComponent("locale-worksheets")
    }

    var siteWorksheets: URL {
        worksheets.appendingPathComponent("site")
    }

    func worksheetDir(site: Bool) -> URL {
        site ? siteWorksheets : worksheets
    }

    /// Which tree a fixture file belongs in, by name — the same
    /// split the shipped tools make. Used when *writing* a
    /// fixture, so its layout mirrors the real one; the queries
    /// above and below name their directory instead.
    func dir(forFile name: String, site: Bool) -> URL {
        name.hasPrefix("missing_")
            ? worksheetDir(site: site) : dir(site: site)
    }

    func worksheetExists(
        _ name: String,
        site: Bool = false
    ) -> Bool {
        FileManager.default.fileExists(
            atPath: worksheetDir(site: site)
                .appendingPathComponent(name).path
        )
    }

    /// Raw bytes of a worksheet — its `{key: {source,
    /// translation}}` shape is not a flat map, so there is no
    /// decoding sibling.
    func rawWorksheet(
        _ name: String,
        site: Bool = false
    ) throws -> Data {
        try Data(
            contentsOf: worksheetDir(site: site)
                .appendingPathComponent(name)
        )
    }
}
