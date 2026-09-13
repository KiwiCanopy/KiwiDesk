import Foundation
import Testing

@testable import KiwiDesk

/// Where About's License and Acknowledgements links point (#1407),
/// and that About is where they are drawn.
///
/// The bundled `.txt` is what `scripts/build-app.sh` ships, so the
/// first half is exercised against a bundle that carries one and
/// against one that does not — the dev binary — rather than
/// against whichever this test process happens to be.
@Suite("License documents")
struct LicenseDocumentsTests {
    @Test("a bundled text is opened in place")
    func bundledTextWins() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "LicenseDocuments-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: dir) }
        let shipped = dir.appendingPathComponent("LICENSE.txt")
        try "text".write(to: shipped, atomically: true, encoding: .utf8)
        let bundle = try #require(Bundle(url: dir))

        let url = LicenseDocuments.document("LICENSE", in: bundle)
        #expect(url.isFileURL)
        #expect(
            url.standardizedFileURL.path
                == shipped.standardizedFileURL.path
        )
        // The sibling is absent from this bundle, so it falls
        // back — per document, never per bundle.
        #expect(
            !LicenseDocuments.document("ACKNOWLEDGEMENTS", in: bundle)
                .isFileURL
        )
    }

    /// The dev binary under `.build/` ships no texts, so each
    /// link opens the same file where GitHub renders it.
    @Test("without a bundled text the link opens GitHub's copy")
    func fallbackIsTheRepositoryFile() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "LicenseDocuments-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: dir) }
        let bundle = try #require(Bundle(url: dir))
        for name in ["LICENSE", "ACKNOWLEDGEMENTS"] {
            let url = LicenseDocuments.document(name, in: bundle)
            #expect(
                url.absoluteString
                    == SupportLinks.gitHub.absoluteString
                    + "/blob/main/\(name)",
                Comment(rawValue: url.absoluteString)
            )
        }
        // No plist, no copyright line — About draws nothing
        // rather than a placeholder.
        #expect(LicenseDocuments.copyright(in: bundle) == nil)
    }

    /// About MOUNTS the row, and is the only reader of the two
    /// URLs. Keyed on the mount line, not the declaration: the
    /// `GuideLinkSurfaceTests` lesson, where deleting the bare
    /// `guideLink` line from the card left every guard green.
    @Test("About draws the row, and nothing else reads the URLs")
    func aboutIsTheOneSurface() throws {
        let tree = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let about = SourceScan.stripComments(
            try String(
                contentsOf: tree.appendingPathComponent(
                    "Settings/Sections/GeneralSection+About.swift"
                ),
                encoding: .utf8
            )
        )
        #expect(
            about.split(separator: "\n").contains {
                $0.trimmingCharacters(in: .whitespaces) == "licenseRow"
            },
            "About no longer mounts the license row"
        )
        for document in ["license", "acknowledgements"] {
            let readers = try SourceScan.swiftSources(under: tree)
                .filter { file in
                    SourceScan.stripComments(
                        try String(contentsOf: file, encoding: .utf8)
                    )
                    .contains("LicenseDocuments.\(document)")
                }
                .map { $0.lastPathComponent }
            #expect(
                readers == ["GeneralSection+About.swift"],
                Comment(
                    rawValue:
                        "LicenseDocuments.\(document) is read in "
                        + "\(readers); About is its one surface"
                )
            )
        }
    }
}
