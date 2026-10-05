import Foundation
import Testing

/// Every store that writes migrated bytes back keeps the original
/// first (#1880): `MigrationBackup.write` is the one door, since
/// `MigrationBackupTests` drives the profile store alone.
@Suite("Migration backup seam (#1880)")
struct MigrationBackupSeamTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    @Test("a migrated rewrite goes through MigrationBackup")
    func everyRewriteKeepsACopy() throws {
        var routed: [String] = []
        for file in try SourceScan.swiftSources(under: Self.core) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let name = file.lastPathComponent
            // The door itself writes after its copy.
            guard name != "MigrationBackup.swift" else { continue }
            #expect(
                !source.contains("migrated.write("),
                "\(name) writes migrated bytes without a copy"
            )
            if source.contains("MigrationBackup.write(") {
                routed.append(name)
            }
        }
        #expect(
            routed.sorted() == [
                "GuiConfigStore.swift", "LookStore.swift",
                "PaletteStore.swift", "ProfileManager.swift",
            ]
        )
    }
}
