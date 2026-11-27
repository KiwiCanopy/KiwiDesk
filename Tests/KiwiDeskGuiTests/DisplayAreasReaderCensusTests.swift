import Foundation
import Testing

/// A split is stored as a screen number's shares (#3647 ▸ lane 3)
/// and reaches points through `ScreenShares+Order` alone, so a reader
/// indexing `display_areas` by fingerprint — the pre-lane-3 shape,
/// which still compiles against a `[String: _]` — reads nothing. Every
/// file spelling `.displayAreas[` is classified here with its reason;
/// a new one reds until it reads through the projection or argues
/// its place. Its blind spot: an index through a renamed copy of the
/// map (`let shares = …displayAreas; shares[fp]`), which is review's.
@Suite("display_areas readers are classified (#3647)")
struct DisplayAreasReaderCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources")

    /// Each file that indexes the stored map, and by what.
    private static let allowed: [String: String] = [
        "KiwiDeskCore/App/KiwiCore+ScreenAreas.swift":
            "the store door, by the number the live order gives",
        "KiwiDeskCore/App/KiwiCore+LuaAreaSplits.swift":
            "the load's reset, by the number Lua's record holds",
        "KiwiDeskCore/Commands/KiwiCore+DisplayAreaCommands.swift":
            "the verbs, by the number a split or `N#id` names",
        "KiwiDeskCore/Profiles/KiwiCore+DesktopAreaSpaces.swift":
            "the Desktop memory, by its `N#id` slot's number",
        "KiwiDesk/Settings/SettingsModel+ScreenAreaEdits.swift":
            "a merge back to whole, by the draft's number",
        "KiwiDesk/Settings/Census/SettingKey+Screens.swift":
            "the census id's spelling, no read",
    ]

    @Test("every file indexing display_areas is classified")
    func readersAreClassified() throws {
        let prefix = Self.root.path + "/"
        var found: Set<String> = []
        for file in try SourceScan.swiftSources(under: Self.root) {
            let source = try String(contentsOf: file, encoding: .utf8)
            guard source.contains(".displayAreas[") else { continue }
            found.insert(String(file.path.dropFirst(prefix.count)))
        }
        #expect(!found.isEmpty, "the scan found the readers")
        #expect(
            found == Set(Self.allowed.keys),
            Comment(rawValue: "indexing display_areas: \(found.sorted())")
        )
    }
}
