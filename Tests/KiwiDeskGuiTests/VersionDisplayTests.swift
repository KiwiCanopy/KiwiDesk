import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The commit stamp reaches the CLI and stops there (#1174).
///
/// Settings is used mostly by non-developers, and a hex blob
/// after the version is noise they cannot interpret — while
/// support and debugging still want it, so it stays on
/// `kiwidesk --version` and as the `version` command's own
/// field. The two GUI surfaces render `semantic` through one
/// localized frame: they say the same thing about the same
/// value, so a second key would be a second translation of one
/// sentence.
@Suite("Version display (#1174)")
struct VersionDisplayTests {
    private var sources: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
    }

    private func swiftFiles(under root: URL) throws -> [URL] {
        let walker = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil
        )
        var found: [URL] = []
        while let url = walker?.nextObject() as? URL {
            if url.pathExtension == "swift" { found.append(url) }
        }
        return found
    }

    /// A file's code with comments and whitespace removed.
    ///
    /// Both, and each closes a hole the other leaves: a comment
    /// naming the symbol would stand in for a deleted call site
    /// (clause 2) or invent a reader that does not exist
    /// (clause 1), and `swift format` may wrap a member access
    /// across lines under the 79-char limit, which a per-line
    /// substring test cannot see (#1069's shape).
    private func code(at file: URL) throws -> String {
        let text = try String(contentsOf: file, encoding: .utf8)
        return
            text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter {
                !$0.trimmingCharacters(in: .whitespaces)
                    .hasPrefix("//")
            }
            .joined()
            .filter { !$0.isWhitespace }
    }

    @Test("Only the CLI renders the commit stamp")
    func displayStringHasOneReader() throws {
        // The property's own file is excluded by name: its
        // declaration is not a read, and excluding it by name
        // rather than by counting keeps a docstring edit there
        // from moving this number either way.
        let files = try swiftFiles(under: sources)
        try #require(
            files.count > 100,
            "only scanned \(files.count) source files"
        )
        var readers: [String] = []
        for file in files
        where file.lastPathComponent != "KiwiDeskVersion.swift" {
            guard
                try code(at: file).contains(
                    "KiwiDeskVersion.displayString"
                )
            else { continue }
            readers.append(file.lastPathComponent)
        }
        #expect(
            readers == ["CLIMain.swift"],
            """
            the commit stamp reached a second surface — Settings \
            renders `semantic` alone (#1174)
            """
        )
    }

    @Test("Both GUI surfaces share one version frame")
    func guiSurfacesShareTheFrame() throws {
        // Scoped to `Settings/`, and what that TRADES: a version
        // rendered from Onboarding or the menu bar would not
        // appear here. The clause above is what makes that safe
        // — it bars the COMMIT from any such site, whatever
        // frame it used — so this one holds the narrower claim
        // that the two Settings surfaces do not drift apart.
        let settings =
            sources
            .appendingPathComponent("KiwiDesk")
            .appendingPathComponent("Settings")
        var framed: [String] = []
        for file in try swiftFiles(under: settings) {
            guard
                try code(at: file).contains("\"general.version\"")
            else { continue }
            framed.append(file.lastPathComponent)
        }
        #expect(
            framed.sorted() == [
                "GeneralSection+About.swift",
                "HomeCardPreview.swift",
            ]
        )
    }
}
