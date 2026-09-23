import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A Desktop binding's entry list is written through the
/// record's own algebra — `bind`, `unbind`, `rename` on
/// `DesktopBinding` — and never by a hand edit of `entries`
/// beside a call site (#1436, #1609, profiles.md). The GUI's slot
/// write shipped as such a hand copy and could drop a pick on a
/// record holding two entries of one count.
@Suite("Desktop binding writer seam (#1436)")
struct DesktopBindingWriterSeamTests {
    /// The one file that may mutate the list.
    private let home = "Sources/KiwiDeskCore/Models/DesktopBinding.swift"

    /// Every spelling of a list edit outside the algebra — the
    /// mutators by name, and any subscript or assignment on the
    /// member, whatever the receiver is called. `self.profiles =`
    /// is another type's own init (a manager, a bundle).
    private let needles = [
        ".entries.append(",
        ".entries.insert(",
        ".entries.remove",
        ".entries.swapAt(",
        ".entries.replaceSubrange(",
        ".entries += ",
        ".entries -= ",
        ".entries[",
        ".entries = ",
    ]
    private let exempt = ["self.entries = "]

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
                        source.occurrences(of: "entries.append(")
                        + source.occurrences(of: "entries.removeAll")
                        + source.occurrences(of: "entries = ")
                    continue
                }
                var scrubbed = source
                for spelling in exempt {
                    scrubbed = scrubbed.replacingOccurrences(
                        of: spelling,
                        with: ""
                    )
                }
                let hits = needles.map { scrubbed.occurrences(of: $0) }
                    .reduce(0, +)
                if hits > 0 { strays.append(file.lastPathComponent) }
            }
        }
        // Vacuity: the algebra itself must be seen, or the
        // needles no longer match how the list is spelled.
        #expect(homeEdits >= 3)
        // A fresh record built around a hand-made list bypasses
        // the algebra unseen by the needles, so its construction
        // sites are counted: the two empty seeds a bind then
        // fills (the model's own convenience init spells
        // `self.init`).
        var constructions: [String: Int] = [:]
        for tree in ["Sources/KiwiDeskCore", "Sources/KiwiDesk"] {
            let dir = root.appendingPathComponent(tree)
            for file in try SourceScan.swiftSources(under: dir) {
                // Squashed, since the formatter wraps the init.
                let source = SourceScan.stripComments(
                    try String(contentsOf: file, encoding: .utf8)
                )
                .split(whereSeparator: \.isWhitespace)
                .joined()
                // Either seeding init: a list of entries built by
                // hand bypasses the algebra the same way (#1609).
                let hits =
                    source.occurrences(of: "DesktopBinding(profiles:")
                    + source.occurrences(of: "DesktopBinding(entries:")
                if hits > 0 { constructions[file.lastPathComponent] = hits }
            }
        }
        #expect(
            constructions == [
                "KiwiCore+Desktops.swift": 1,
                "DesktopsGroup+Write.swift": 1,
            ],
            Comment(
                rawValue:
                    "\(constructions): a new DesktopBinding(profiles:) "
                    + "site seeds a list by hand; go through bind"
            )
        )
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
