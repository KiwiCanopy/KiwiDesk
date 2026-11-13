import Foundation
import Testing

@testable import KiwiDesk

/// Where About's License and Acknowledgements links point (#1407),
/// that the GUI's roster is the packager's, and that About is
/// where they are drawn.
///
/// The bundled `.txt` is what `scripts/build-app.sh` ships, so
/// the resolution is exercised against a bundle that carries one
/// and against one that does not — the dev binary — rather than
/// against whichever this test process happens to be.
@Suite("License documents")
struct LicenseDocumentsTests {
    private var tree: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
    }

    private func temporaryBundle() throws -> (Bundle, URL) {
        let dir =
            testTemporaryDirectory
            .appendingPathComponent(
                "LicenseDocuments-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        return (try #require(Bundle(url: dir)), dir)
    }

    @Test("a bundled text is shown in KiwiDesk")
    func bundledTextWins() throws {
        let (bundle, dir) = try temporaryBundle()
        defer { try? FileManager.default.removeItem(at: dir) }
        let shipped = dir.appendingPathComponent("LICENSE.txt")
        try "text".write(to: shipped, atomically: true, encoding: .utf8)

        guard
            case .bundled(let url) = LicenseDocuments.source(
                for: .license,
                in: bundle
            )
        else {
            Issue.record("a bundled text must open in KiwiDesk")
            return
        }
        #expect(
            url.standardizedFileURL.resolvingSymlinksInPath().path
                == shipped.standardizedFileURL
                .resolvingSymlinksInPath().path
        )
        #expect(LicenseDocuments.text(at: url) == "text")
        // The sibling is absent from this bundle, so it falls
        // back — per document, never per bundle.
        guard
            case .link = LicenseDocuments.source(
                for: .acknowledgements,
                in: bundle
            )
        else {
            Issue.record("a missing text must fall back to a link")
            return
        }
    }

    /// The dev binary under `.build/` ships no texts, so each
    /// link opens the same file where GitHub renders it — a plain
    /// link, never an empty sheet (#3286).
    @Test("without a bundled text the link opens GitHub's copy")
    func fallbackIsTheRepositoryFile() throws {
        let (bundle, dir) = try temporaryBundle()
        defer { try? FileManager.default.removeItem(at: dir) }
        for document in LicenseDocuments.Document.allCases {
            let url = URL(
                string: SupportLinks.gitHub.absoluteString
                    + "/blob/main/\(document.rawValue)"
            )!
            #expect(
                LicenseDocuments.source(for: document, in: bundle)
                    == .link(url)
            )
        }
        // No plist, no copyright line — About draws nothing
        // rather than a placeholder.
        #expect(LicenseDocuments.copyright(in: bundle) == nil)
    }

    /// The names the GUI asks the bundle for are the names the
    /// packager writes — one roster, read off the script's own
    /// `for doc in` line. A drift on either side is an About
    /// link that opens a GitHub page instead of the shipped text,
    /// and nothing else crosses that seam.
    @Test("the GUI's roster is the packager's")
    func rosterMatchesTheScript() throws {
        let script = try String(
            contentsOf: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent("scripts/build-app.sh"),
            encoding: .utf8
        )
        let line = try #require(
            script.split(separator: "\n").first {
                $0.trimmingCharacters(in: .whitespaces)
                    .hasPrefix("for doc in ")
            },
            "build-app.sh's license-text loop is gone"
        )
        let scripted = Set(
            line.trimmingCharacters(in: .whitespaces)
                .dropFirst("for doc in ".count)
                .split(separator: ";").first!
                .split(separator: " ")
                .map(String.init)
        )
        #expect(
            scripted
                == Set(
                    LicenseDocuments.Document.allCases.map(\.rawValue)
                ),
            Comment(rawValue: "\(scripted.sorted())")
        )
    }

    /// About MOUNTS the row, and is the only reader of the texts
    /// and the copyright line. Keyed on the mount line, not the
    /// declaration — gui.md's rule: key a needle on the site that
    /// USES the value, since a needle on a declaration stayed
    /// green once when About's bare mount line was deleted
    /// (code-reviewer, 2026-08-26).
    @Test("About draws the row, and nothing else reads the texts")
    func aboutIsTheOneSurface() throws {
        let about = SourceScan.stripComments(
            try String(
                contentsOf: tree.appendingPathComponent(
                    "Settings/Home/AboutSheet.swift"
                ),
                encoding: .utf8
            )
        )
        #expect(
            about.split(separator: "\n").contains {
                $0.trimmingCharacters(in: .whitespaces) == "links"
            },
            "About no longer mounts its links row"
        )
        // One link per document, derived: a case joining
        // `Document` and the script keeps the roster guard green
        // while About draws nothing for it.
        for (needle, count) in [
            (
                "LicenseDocuments.source(for:",
                LicenseDocuments.Document.allCases.count
            ),
            ("LicenseDocuments.copyright", 1),
        ] {
            let readers = try SourceScan.swiftSources(under: tree)
                .filter { file in
                    SourceScan.stripComments(
                        try String(contentsOf: file, encoding: .utf8)
                    )
                    .contains(needle)
                }
                .map { $0.lastPathComponent }
            #expect(
                readers == ["AboutSheet.swift"],
                Comment(
                    rawValue:
                        "\(needle) is read in \(readers); About is "
                        + "its one surface"
                )
            )
            #expect(
                about.occurrences(of: needle) == count,
                Comment(rawValue: "\(needle) drawn \(count)× in About")
            )
        }
    }
}
