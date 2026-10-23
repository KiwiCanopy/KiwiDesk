import Foundation
import Testing

/// `migratingRetiredWrapFocus` drops `wrap_focus` at any depth
/// (#2493), unscoped by parent, so a setting that declared that key
/// again would be deleted from every file by the crossing. Only the
/// step's own file may name the key; a new declarer owes the step a
/// path first. Comments are stripped, so prose naming it is free.
@Suite("Wrap focus key scope (#2493)")
struct WrapFocusKeyScopeTests {
    @Test("only the crossing names the retired key")
    func retiredKeyHasOneHome() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
        let prefix = root.path + "/"
        var naming: Set<String> = []
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            if source.contains("\"wrap_focus\"") {
                naming.insert(String(file.path.dropFirst(prefix.count)))
            }
        }
        // Non-vacuity: the step itself must be found.
        #expect(
            naming == ["KiwiDeskCore/Config/ConfigMigration+FocusWrap.swift"]
        )
    }
}
