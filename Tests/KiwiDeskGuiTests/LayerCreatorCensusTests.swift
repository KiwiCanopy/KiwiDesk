import Foundation
import Testing

/// Every page-side layer creator goes through the one recording
/// decider (#2022): a layer the page gains with no membership record
/// is decided nowhere, and its rows are dropped in a release build,
/// where `RuleReachTable.setRows` asserts only in debug. The census
/// counts each spelling that gives a layer list a layer — on ANY
/// receiver, since a creator may mutate a local copy before handing
/// it back — across the GUI tree against this register, and the
/// renames beside it against theirs.
struct LayerCreatorCensusTests {
    /// Mutations that give a `.layers` list a layer, any receiver.
    private static let creatorPatterns = [
        #"\.layers\.append\("#,
        #"\.layers\.insert\("#,
        #"\.layers \+= "#,
        #"\.layers = KeybindingCatalog\.insertLayer\("#,
        #"KeybindingMerge\.merge\("#,
    ]

    /// File (relative to Sources/KiwiDesk) → how many creators.
    private static let creators: [String: Int] = [
        // Add's new layer and its rejoin, and Import's merge — all
        // three recorded through `layerAdmission`.
        "Settings/SettingsModel+LayerAdd.swift": 3
    ]

    /// A rename moves a layer and creates none, so it is registered
    /// apart, each with the record it keeps.
    private static let renamers: [String: (Int, String)] = [
        "Settings/SettingsModel+LayerReachEdit.swift": (
            1,
            "the page's rename, recorded as the LayerEdit's stored name"
        ),
        "Settings/SettingsModel+LayerAdd.swift": (
            1,
            "Import's free name, applied before the merge it records"
        ),
        "Settings/SettingsModel+LayerPass.swift": (
            2,
            "the layer pass's own rename map, over the virtual files"
        ),
    ]

    @Test("every page-side layer creator is the recording decider's")
    func creatorsAreRegistered() throws {
        let found = try Self.count(Self.creatorPatterns)
        #expect(
            found == Self.creators,
            "a layer creator outside the register: \(found)"
        )
    }

    @Test("every layer rename is registered with its record")
    func renamersAreRegistered() throws {
        let found = try Self.count([#"KeybindingCatalog\.renameLayer\("#])
        #expect(found == Self.renamers.mapValues(\.0))
    }

    private static func count(_ patterns: [String]) throws
        -> [String: Int]
    {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let regexes = try patterns.map { try NSRegularExpression(pattern: $0) }
        var found: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let source = try SourceScan.strippedSource(at: file)
            let range = NSRange(source.startIndex..., in: source)
            let count = regexes.reduce(0) {
                $0 + $1.numberOfMatches(in: source, range: range)
            }
            guard count > 0 else { continue }
            let path =
                file.path.components(separatedBy: "/Sources/KiwiDesk/").last
                ?? file.path
            found[path] = count
        }
        return found
    }
}
