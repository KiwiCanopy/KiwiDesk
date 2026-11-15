import Foundation
import Testing

@testable import KiwiDesk

/// Every row that mounts a key recorder lays out through
/// `ShortcutKeyRow` (#3258 ▸ owner ruling), so a refused chord's
/// conflict line spans the row on every kind of row. `mounts` is the
/// one copy of who may mount a recorder, each beside the file whose
/// row hosts it; a new mount joins it with its host.
@Suite("Shortcut key rows host their conflict line (#3258)")
struct ShortcutKeyRowSeamTests {
    private static let tree = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDesk")

    /// Recorder mount → the file drawing the row around it, and the
    /// recorder's call as that row's content spells it. A mount whose
    /// recorder sits in a helper names the helper: the scan follows
    /// one hop by name and does not read the helper's body.
    private static let mounts: [String: (host: String, inside: String)] = [
        "Settings/Components/Keybindings/KeybindingNavRow.swift": (
            "Settings/Components/Keybindings/KeybindingNavRow.swift",
            "KeyRecorderField("
        ),
        "Settings/Components/Keybindings/KeybindingAppGroup+Row.swift": (
            "Settings/Components/Keybindings/KeybindingAppGroup+Row.swift",
            "KeyRecorderField("
        ),
        "Settings/Components/Keybindings/PocketAppRows.swift": (
            "Settings/Components/Keybindings/PocketAppRows.swift",
            "KeyRecorderField("
        ),
        "Settings/Components/Lua/AdvancedLuaGroup+Row.swift": (
            "Settings/Components/Lua/AdvancedLuaGroup+Row.swift",
            "recorder(binding,name:name)"
        ),
        "Settings/Components/Keybindings/Sequences/"
            + "SequenceNodeRow+Recorder.swift": (
                "Settings/Components/Keybindings/Sequences/"
                    + "SequenceNodeRow.swift",
                "{leaderLine}else{keyLine}"
            ),
    ]

    /// The content of the first `ShortcutKeyRow` call in `source`,
    /// whitespace dropped, nil where there is none.
    private static func rowContent(_ source: String) -> String? {
        let text = source.filter { !$0.isWhitespace }
        guard let call = text.range(of: "ShortcutKeyRow"),
            let open = text[call.upperBound...].firstIndex(of: "{")
        else { return nil }
        var depth = 0
        var index = open
        while index < text.endIndex {
            switch text[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    return String(text[text.index(after: open)..<index])
                }
            default: break
            }
            index = text.index(after: index)
        }
        return nil
    }

    private static func source(_ path: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: tree.appendingPathComponent(path),
                encoding: .utf8
            )
        )
    }

    @Test("the register is every recorder mount")
    func registerIsComplete() throws {
        let files = try FileManager.default
            .subpathsOfDirectory(atPath: Self.tree.path)
            .filter { $0.hasSuffix(".swift") }
        var found: Set<String> = []
        for file in files where !file.contains("/Recorder/") {
            if try Self.source(file).contains("KeyRecorderField(") {
                found.insert(file)
            }
        }
        #expect(found == Set(Self.mounts.keys))
    }

    @Test("each mount's recorder is inside its ShortcutKeyRow")
    func rowsTakeTheDoor() throws {
        for (mount, row) in Self.mounts {
            let content = Self.rowContent(try Self.source(row.host))
            #expect(content?.contains(row.inside) == true, "\(mount)")
        }
    }
}
