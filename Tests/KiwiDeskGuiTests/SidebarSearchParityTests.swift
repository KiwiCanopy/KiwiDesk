import Foundation
import Testing

/// The search index is a second mirror of the subsection-title
/// list (.claude/rules/parity-tests.md): the titles live once
/// at their `SettingsSection(...)` call sites and once in
/// `SidebarSearch.subsections(of:)`. This guard scans the
/// sources so a section header that is removed or renamed in a
/// view fails here instead of leaving search silently stale —
/// `extract-keys --check` already pins the other direction
/// (same key must carry the same English everywhere).
@Suite("Sidebar search index parity")
struct SidebarSearchParityTests {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KiwiDeskGuiTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
    }

    private var settingsDir: URL {
        repoRoot.appendingPathComponent(
            "Sources/KiwiDesk/Settings"
        )
    }

    @Test("every index key has a rendering call site")
    func indexKeysHaveRenderingCallSites() throws {
        let indexFile = settingsDir.appendingPathComponent(
            "SidebarSearch.swift"
        )
        let indexKeys = try lKeys(
            in: String(
                contentsOf: indexFile,
                encoding: .utf8
            )
        )
        // The regex and the file path both went stale if this
        // fires — an empty key set would vacuously pass below.
        #expect(!indexKeys.isEmpty)

        var rendered = Set<String>()
        for file in try swiftSources(under: settingsDir)
        where file.lastPathComponent != "SidebarSearch.swift" {
            rendered.formUnion(
                try lKeys(
                    in: String(
                        contentsOf: file,
                        encoding: .utf8
                    )
                )
            )
        }
        for key in indexKeys {
            #expect(
                rendered.contains(key),
                "stale search index key: \(key)"
            )
        }
    }

    /// Every `L("key", ...)` literal in a source string; the
    /// pattern tolerates the 79-char style's line break
    /// between `L(` and the key.
    private func lKeys(in source: String) throws -> Set<String> {
        let pattern = #"L\(\s*"([a-z0-9_.]+)""#
        let regex = try NSRegularExpression(
            pattern: pattern
        )
        let range = NSRange(
            source.startIndex...,
            in: source
        )
        var keys = Set<String>()
        regex.enumerateMatches(
            in: source,
            range: range
        ) { match, _, _ in
            guard
                let match,
                let keyRange = Range(
                    match.range(at: 1),
                    in: source
                )
            else { return }
            keys.insert(String(source[keyRange]))
        }
        return keys
    }

    private func swiftSources(
        under directory: URL
    ) throws -> [URL] {
        let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil
        )
        var files: [URL] = []
        while let item = enumerator?.nextObject() as? URL {
            if item.pathExtension == "swift" {
                files.append(item)
            }
        }
        return files
    }
}
