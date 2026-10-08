import Foundation
import Testing

/// Every page-side layer creator goes through the one recording
/// decider (#2022): a layer the page gains with no membership record
/// is decided nowhere, and its rows are dropped in a release build,
/// where `RuleReachTable.setRows` asserts only in debug. The census
/// counts each spelling that gives the page a layer, across the GUI
/// tree, against this register — a new creator joins it, and only
/// through `SettingsModel.layerAdmission`'s file.
struct LayerCreatorCensusTests {
    /// The spellings that give the page a layer.
    private static let needles = [
        "config.layers.append(",
        "config.layers.insert(",
        "config.layers += ",
        "config.layers = KeybindingCatalog.insertLayer(",
        "KeybindingMerge.merge(",
    ]

    /// File (relative to Sources/KiwiDesk) → how many creators.
    private static let creators: [String: Int] = [
        // Add's new layer and its rejoin, and Import's merge.
        "Settings/SettingsModel+LayerAdd.swift": 3
    ]

    @Test("every page-side layer creator is the recording decider's")
    func creatorsAreRegistered() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var found: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let source = try SourceScan.strippedSource(at: file)
            let count = Self.needles.reduce(0) { total, needle in
                total + source.components(separatedBy: needle).count - 1
            }
            guard count > 0 else { continue }
            let path =
                file.path.components(separatedBy: "/Sources/KiwiDesk/").last
                ?? file.path
            found[path] = count
        }
        #expect(
            found == Self.creators,
            "a page-side layer creator outside the register: \(found)"
        )
    }
}
