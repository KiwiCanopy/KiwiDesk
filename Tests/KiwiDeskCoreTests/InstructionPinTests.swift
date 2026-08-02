import Foundation
import Testing

/// The two pins in `.claude/` that fail *silently* when they rot.
///
/// `RuleCitationTests` resolves what an instruction file cites in
/// its prose. This resolves the two things it cannot see:
///
/// 1. A **literal `paths:` entry**. The loader matches a glob
///    against the file being edited; an entry matching nothing is
///    indistinguishable from an entry whose file is simply not
///    open. So a rule pinned to one file — `os-private-apis.md`
///    reaches `AX/AXHelper.swift` so the `@_silgen_name` carve-out
///    arrives where the exemption lives — stops arriving the day
///    that file is renamed, and nothing says so. `AXHelper.swift`
///    is also exactly the shape the §2.1 ceiling splits.
/// 2. A **deleted agent**. `subagents.md` loads when an agent file
///    is added or edited, so its roster table is on screen then;
///    `rm` matches no glob, so it is not. The table is the one
///    place a removed agent lingers.
///
/// Globs are deliberately not resolved — `Tests/**` matching
/// nothing would mean the tree is gone, and a glob that matches
/// nothing *today* can still be the right rule tomorrow.
@Suite("Instruction file pins")
struct InstructionPinTests {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KiwiDeskCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
    }

    private var claude: URL {
        repoRoot.appendingPathComponent(".claude")
    }

    @Test("Every literal paths: entry resolves")
    func literalPathPinsResolve() throws {
        var missing: [String] = []
        var seen = 0
        for (file, text) in try documents(in: "rules") {
            for pin in Self.pathEntries(text)
            where !pin.contains("*") && !pin.contains("?") {
                seen += 1
                let url = repoRoot.appendingPathComponent(pin)
                if !FileManager.default.fileExists(atPath: url.path) {
                    missing.append("\(file): \(pin)")
                }
            }
        }
        #expect(missing.isEmpty, "dangling path pins: \(missing)")
        // A walk that finds nothing would pass for the wrong
        // reason, so pin the floor to the shape of the register:
        // the literal pins are a minority of all `paths:` entries,
        // but there is always more than one.
        #expect(seen > 1, "only saw \(seen) literal path pins")
    }

    @Test("The roster and the directory agree, both ways")
    func rosterMatchesDirectory() throws {
        let roster = try String(
            contentsOf:
                claude
                .appendingPathComponent("rules")
                .appendingPathComponent("subagents.md"),
            encoding: .utf8
        )
        let onDisk = Set(
            try documents(in: "agents").map { name, _ in
                (name as NSString).deletingPathExtension
            }
        )
        let listed = Set(Self.rosterRowNames(roster))
        // Both sets derive from the tree — neither is hand-listed
        // here, which is what keeps this from being a tautology.
        #expect(!onDisk.isEmpty, "no agents found")
        #expect(!listed.isEmpty, "no roster rows parsed")
        // Set equality, not containment. Containment in either
        // direction alone is inert against the failure it names:
        // checking only that every agent is listed lets a deleted
        // agent take itself out of the comparison, which is
        // precisely the rot the roster is exposed to (`rm` matches
        // no glob, so subagents.md never loads to be corrected).
        let stale = listed.subtracting(onDisk).sorted()
        let unlisted = onDisk.subtracting(listed).sorted()
        #expect(stale.isEmpty, "roster rows with no agent: \(stale)")
        #expect(
            unlisted.isEmpty,
            "agents missing a roster row: \(unlisted)"
        )
    }

    /// Every `.md` under `.claude/<directory>`, as (name, text).
    private func documents(
        in directory: String
    ) throws -> [(String, String)] {
        let root = claude.appendingPathComponent(directory)
        let names = try FileManager.default
            .contentsOfDirectory(atPath: root.path)
            .filter { $0.hasSuffix(".md") }
            .sorted()
        #expect(!names.isEmpty, "no .md files in \(directory)")
        return try names.map { name in
            (
                name,
                try String(
                    contentsOf: root.appendingPathComponent(name),
                    encoding: .utf8
                )
            )
        }
    }

    /// The quoted entries of a leading `paths:` YAML block.
    ///
    /// Stops at the first key that is not a list item, so a later
    /// frontmatter key cannot leak its values in. Comment lines are
    /// skipped — several rule files comment inside the block.
    static func pathEntries(_ text: String) -> [String] {
        var out: [String] = []
        var inPaths = false
        for line in text.split(
            separator: "\n",
            omittingEmptySubsequences: false
        ) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" && inPaths { break }
            if trimmed.hasPrefix("#") { continue }
            if trimmed == "paths:" {
                inPaths = true
                continue
            }
            guard inPaths else { continue }
            guard trimmed.hasPrefix("- ") else {
                if !trimmed.isEmpty { break }
                continue
            }
            let value =
                trimmed
                .dropFirst(2)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            if !value.isEmpty { out.append(value) }
        }
        return out
    }

    /// The backticked name in the first cell of each roster row.
    ///
    /// Reads the table rather than every backticked span in the
    /// document: the file names scripts, tool names and prose
    /// symbols in backticks too, and a walk that swept those up
    /// would call any of them an agent.
    static func rosterRowNames(_ text: String) -> [String] {
        text.split(separator: "\n").compactMap { line in
            guard line.hasPrefix("| `") else { return nil }
            let cell = line.dropFirst(2)
            guard
                let open = cell.firstIndex(of: "`"),
                let close = cell[cell.index(after: open)...]
                    .firstIndex(of: "`")
            else { return nil }
            let name = cell[cell.index(after: open)..<close]
            // A row's first cell is a bare agent name; anything
            // with a path separator or a space is another table.
            guard
                !name.isEmpty,
                !name.contains("/"),
                !name.contains(" ")
            else { return nil }
            return String(name)
        }
    }
}
