import Foundation
import Testing

/// The handle stamp's text edit (#3409) writes every `"handle_color"`
/// in the file while its walk stamps only `settings.kiwishelf`: safe
/// exactly while that key is the shelf group's alone. A second
/// stored `handle_color` would send the edit past the walk, and the
/// envelope would then re-serialize every file it stamps, silently.
/// The command setting names the key without declaring it.
@Suite("Config migration routing — the handle stamp")
struct HandleStampRoutingTests {
    @Test("The handle stamp's key has one declarer")
    func handleKeyStaysUnique() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let prefix = root.path + "/"
        let allowed: Set<String> = [
            "Layouts/KiwiShelf+Coding.swift",
            "Config/ConfigMigration+HandleStamp.swift",
            "Commands/KiwiShelfCommandSetting.swift",
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
            if source.contains("\"handle_color\"") {
                declarers.insert(key)
            }
        }
        #expect(!declarers.isEmpty)
        #expect(
            declarers == allowed,
            Comment(
                rawValue:
                    "`handle_color` declared or named in: "
                    + "\(declarers.sorted()) — a second stored "
                    + "`handle_color` sends the stamp's edit past "
                    + "its walk, or this map owes it an entry"
            )
        )
    }
}
