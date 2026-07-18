import Foundation
import Testing

/// Keeps the hand-maintained AGENTS.md subsystem map aligned with
/// the actual top-level KiwiDeskCore directories in both directions.
@Suite("subsystem map parity")
struct SubsystemMapParityTests {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KiwiDeskCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
    }

    @Test("AGENTS.md rows match KiwiDeskCore directories")
    func subsystemRowsMatchDirectories() throws {
        let agentsURL = repoRoot.appendingPathComponent("AGENTS.md")
        let agents = try String(contentsOf: agentsURL, encoding: .utf8)
        let documented = try documentedSubsystems(in: agents)
        let onDisk = try subsystemDirectories()

        let undocumented = onDisk.subtracting(documented).sorted()
        let nonexistent = documented.subtracting(onDisk).sorted()
        #expect(
            undocumented.isEmpty,
            "missing AGENTS.md rows: \(undocumented)"
        )
        #expect(
            nonexistent.isEmpty,
            "AGENTS.md rows without directories: \(nonexistent)"
        )
    }

    private func documentedSubsystems(
        in agents: String
    ) throws -> Set<String> {
        let marker =
            "Subsystem map (`Sources/KiwiDeskCore/*`)"
        guard let markerRange = agents.range(of: marker) else {
            throw MapError.missingMarker
        }

        var rows = Set<String>()
        var insideTable = false
        let suffix = agents[markerRange.upperBound...]
        for line in suffix.split(
            separator: "\n",
            omittingEmptySubsequences: false
        ) {
            if line.hasPrefix("| Dir ") {
                insideTable = true
                continue
            }
            guard insideTable else { continue }
            if line.isEmpty { break }
            guard line.hasPrefix("| `") else { continue }
            let fields = line.split(separator: "`")
            if fields.count > 1 {
                rows.insert(String(fields[1]))
            }
        }
        return rows
    }

    private func subsystemDirectories() throws -> Set<String> {
        let core = repoRoot.appendingPathComponent(
            "Sources/KiwiDeskCore"
        )
        let children = try FileManager.default.contentsOfDirectory(
            at: core,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        return try Set(
            children.compactMap { child in
                let values = try child.resourceValues(
                    forKeys: [.isDirectoryKey]
                )
                return values.isDirectory == true
                    ? child.lastPathComponent
                    : nil
            }
        )
    }

    private enum MapError: Error {
        case missingMarker
    }
}
