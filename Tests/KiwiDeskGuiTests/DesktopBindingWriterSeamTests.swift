import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A Desktop binding's profile list is written through the
/// record's own algebra — `bind`, `unbind`, `rename` on
/// `DesktopBinding` — and never by a hand edit of `profiles`
/// beside a call site (#1436, profiles.md). The GUI's slot
/// write shipped as such a hand copy and could drop a pick on a
/// record holding two entries of one count.
@Suite("Desktop binding writer seam (#1436)")
struct DesktopBindingWriterSeamTests {
    /// The one file that may mutate the list.
    private let home = "Sources/KiwiDeskCore/Models/DesktopBinding.swift"

    /// Every spelling of a list edit outside the algebra.
    private let needles = [
        ".profiles.append(",
        ".profiles.insert(",
        ".profiles.remove",
        "?.profiles = ",
        "binding.profiles = ",
        "record.profiles = ",
    ]

    @Test("the list is edited only through the record's algebra")
    func listHasOneWriter() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        var strays: [String] = []
        var homeEdits = 0
        for tree in ["Sources/KiwiDeskCore", "Sources/KiwiDesk"] {
            let dir = root.appendingPathComponent(tree)
            for file in try SourceScan.swiftSources(under: dir) {
                let source = SourceScan.stripComments(
                    try String(contentsOf: file, encoding: .utf8)
                )
                if file.path.hasSuffix(home) {
                    // The algebra spells its own edits bare.
                    homeEdits +=
                        source.occurrences(of: "profiles.append(")
                        + source.occurrences(of: "profiles.removeAll")
                        + source.occurrences(of: "profiles = ")
                    continue
                }
                let hits = needles.map { source.occurrences(of: $0) }
                    .reduce(0, +)
                if hits > 0 { strays.append(file.lastPathComponent) }
            }
        }
        // Vacuity: the algebra itself must be seen, or the
        // needles no longer match how the list is spelled.
        #expect(homeEdits >= 3)
        #expect(
            strays.isEmpty,
            Comment(
                rawValue:
                    "\(strays) edit a binding's profile list by hand; "
                    + "go through DesktopBinding.bind/unbind/rename"
            )
        )
    }
}
