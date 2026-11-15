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

    /// Recorder mount → the file drawing the row around it.
    private static let mounts: [String: String] = [
        "Settings/Components/Keybindings/KeybindingNavRow.swift":
            "Settings/Components/Keybindings/KeybindingNavRow.swift",
        "Settings/Components/Keybindings/KeybindingAppGroup+Row.swift":
            "Settings/Components/Keybindings/KeybindingAppGroup+Row.swift",
        "Settings/Components/Keybindings/PocketAppRows.swift":
            "Settings/Components/Keybindings/PocketAppRows.swift",
        "Settings/Components/Lua/AdvancedLuaGroup+Row.swift":
            "Settings/Components/Lua/AdvancedLuaGroup+Row.swift",
        "Settings/Components/Keybindings/Sequences/"
            + "SequenceNodeRow+Recorder.swift":
            "Settings/Components/Keybindings/Sequences/"
            + "SequenceNodeRow.swift",
    ]

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

    @Test("each mount's row lays out through ShortcutKeyRow")
    func rowsTakeTheDoor() throws {
        for (mount, host) in Self.mounts {
            let row = try Self.source(host)
            #expect(
                row.contains("ShortcutKeyRow {")
                    || row.contains("ShortcutKeyRow(spacing:"),
                "\(mount)"
            )
        }
    }
}
