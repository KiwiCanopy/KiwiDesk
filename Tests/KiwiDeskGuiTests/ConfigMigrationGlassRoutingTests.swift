import Foundation
import Testing

@testable import KiwiDeskCore

/// The glass fill's scoping clause (#1369), split from
/// `ConfigMigrationRoutingTests` at the tests.md file ceiling:
/// the step lands on `settings` by PATH, so the one thing a
/// second declarer of that key could do is hand the fill a
/// parent it was never scoped to.
@Suite("Config migration routing — the glass fill")
struct ConfigMigrationGlassRoutingTests {
    private var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    /// The glass fill (#1369) and the track-limit lift (#1354)
    /// land on a profile root's `settings` and a bundle root's
    /// `profiles[].settings` by PATH: one CodingKey declares
    /// `settings` as a top-level key, plus each step's own
    /// literal. A second CodingKey declarer is a parent neither
    /// step was scoped to.
    @Test("The settings-path steps have one declarer")
    func glassFillStaysScoped() throws {
        let root = coreRoot
        let prefix = root.path + "/"
        let allowed: Set<String> = [
            "Profiles/Profile.swift",
            "Config/ConfigMigration+GlassDefault.swift",
            "Config/ConfigMigration+TrackLimit.swift",
        ]
        var declarers: Set<String> = []
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let key =
                file.path.hasPrefix(prefix)
                ? String(file.path.dropFirst(prefix.count))
                : file.path
            let declares =
                source.range(
                    of: "case settings(?![A-Za-z0-9_])",
                    options: .regularExpression
                ) != nil && source.contains("CodingKey")
            if declares || source.contains("\"settings\"") {
                declarers.insert(key)
            }
        }
        #expect(
            declarers == allowed,
            Comment(
                rawValue:
                    "`settings` declared in: \(declarers.sorted()) "
                    + "— a second top-level `settings` is a parent "
                    + "the glass fill was never scoped to, or this "
                    + "map owes it an entry"
            )
        )
    }
}
