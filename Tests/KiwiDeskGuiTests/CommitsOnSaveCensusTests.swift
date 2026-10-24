import Foundation
import Testing

/// Every Settings field that keeps its typing local commits through
/// the one `commitsOnSave`, so a Save or a leave hears it (#2584),
/// and every reader of the draft that a typed value must reach asks
/// for the commit first.
@Suite("Commit-on-save census (#2584)")
struct CommitsOnSaveCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let home = "CommitsOnSave.swift"

    private func flat(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(path)
        )
        .split(whereSeparator: \.isWhitespace).joined()
    }

    private func guiFiles() throws -> [(name: String, text: String)] {
        let dir = Self.root.appendingPathComponent("Sources/KiwiDesk")
        let urls = FileManager.default.enumerator(
            at: dir,
            includingPropertiesForKeys: nil
        )?.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        let files = try (urls ?? []).map {
            (
                name: $0.lastPathComponent,
                text: try SourceScan.strippedSource(at: $0)
                    .split(whereSeparator: \.isWhitespace).joined()
            )
        }
        #expect(files.count > 100, "scan read the GUI tree")
        return files
    }

    /// A blur commit spelled by hand is a field the request misses.
    @Test("No field commits on blur beside the one modifier")
    func noHandBlurCommit() throws {
        let files = try guiFiles()
        let joined = files.filter { $0.text.contains(".commitsOnSave($") }
        #expect(joined.count >= 6)
        for file in files where file.name != Self.home {
            #expect(
                file.text.occurrences(of: ".onSubmit(commit)") == 0,
                "\(file.name) commits on Return beside commitsOnSave"
            )
            // A blur commit: `if !<flag> { commit() }`. A key
            // handler calling `commit()` (a picker's Return) is no
            // blur commit and stays out.
            #expect(
                Self.blurCommits(in: file.text) == 0,
                "\(file.name) commits on blur beside commitsOnSave"
            )
        }
    }

    private static func blurCommits(in text: String) -> Int {
        let pattern = try? NSRegularExpression(
            pattern: #"if![A-Za-z_.]+\{commit\(\)\}"#
        )
        return pattern?.numberOfMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        ) ?? 0
    }

    /// The needle sees the shape it guards: the modifier's own body.
    @Test("The blur needle matches the modifier it replaced")
    func needleSeesTheShape() throws {
        let home = try flat("Sources/KiwiDesk/Settings/" + Self.home)
        #expect(Self.blurCommits(in: home) == 1)
    }

    @Test("Each draft reader asks for the commit first")
    func readersAskFirst() throws {
        let dir = "Sources/KiwiDesk/Settings/"
        for (file, head) in [
            (
                "SettingsModel+SaveAction.swift",
                "funcperformPrimarySave(){commitFocusedField()"
            ),
            (
                "SettingsModel+Leave.swift",
                "commitFocusedField()guardisDirtyelse{returnproceed()}"
            ),
            (
                "SettingsModel+Sync.swift",
                "->SyncRefusal?{commitFocusedField()ifisDirty{"
            ),
        ] {
            #expect(
                try flat(dir + file).occurrences(of: head) == 1,
                "\(file) reads the draft before the commit"
            )
        }
        let footer = try flat(dir + "SettingsFooter+Slots.swift")
        #expect(
            footer.occurrences(
                of: "Button(\"\"){model.saveFromKeyboard()}"
                    + ".keyboardShortcut(\"s\")"
            ) == 1
        )
        #expect(footer.occurrences(of: ".keyboardShortcut(\"s\")") == 1)
    }
}
