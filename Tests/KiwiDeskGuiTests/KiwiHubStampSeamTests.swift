import Foundation
import Testing

/// KiwiHub's window carries `KiwiHubSide.panelIdentifier`, stamped
/// in one place, and the own key window reading compares the
/// CLASSIFIED window against it, so a side's tap passes the hold
/// under KiwiHub alone (#1229). An unstamped KiwiHub holds every
/// tap; a second stamp, on a grown peek, would let side taps pass
/// there. The read's default is `false`, so a dropped read
/// compiles; this census is what reds it.
///
/// Both needles are scanned, the constant's name and its raw
/// value, as `OwnWindowTilingSeamTests` does for its mark. Same
/// disclosed limit: `stripComments` cuts a line at its first `//`.
@Suite("KiwiHub panel stamp seam (#1229)")
struct KiwiHubStampSeamTests {
    private let needles = ["panelIdentifier", "kiwidesk.kiwihub"]

    /// Repo-relative file -> how many times it may name the stamp:
    /// the declaration (name and literal), the one stamp, the one
    /// read.
    private let allowed = [
        "Sources/KiwiDeskCore/Commands/KiwiCore+KiwiHub.swift": 2,
        "Sources/KiwiDesk/Jump/JumpPanelController.swift": 1,
        "Sources/KiwiDeskCore/Events/EventLoop+RaiseStandDown.swift": 1,
    ]

    private static var root: URL {
        SourceScan.repoRoot(from: #filePath)
    }

    private static var scanRoots: [URL] {
        ["KiwiDesk", "KiwiDeskCore"].map {
            root.appendingPathComponent("Sources")
                .appendingPathComponent($0)
        }
    }

    @Test("the stamp is declared, stamped and read once each")
    func stampCensus() throws {
        let prefix = Self.root.path + "/"
        var counts: [String: Int] = [:]
        for tree in Self.scanRoots {
            let files = try SourceScan.swiftSources(under: tree)
            #expect(!files.isEmpty, "\(tree.lastPathComponent) read")
            for file in files {
                let source = SourceScan.stripComments(
                    try String(contentsOf: file, encoding: .utf8)
                )
                let hits = needles.reduce(0) {
                    $0 + source.occurrences(of: $1)
                }
                guard hits > 0 else { continue }
                counts[String(file.path.dropFirst(prefix.count))] = hits
            }
        }
        #expect(counts == allowed)
    }

    /// The read compares the classified window, the one the other
    /// facets read, so a sheet over KiwiHub would classify as it.
    @Test("the reading compares the classified window")
    func readsTheClassifiedWindow() throws {
        let file = Self.root.appendingPathComponent(
            "Sources/KiwiDeskCore/Events/EventLoop+RaiseStandDown.swift"
        )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        .filter { !$0.isWhitespace }
        #expect(!source.isEmpty)
        #expect(
            source.contains(
                "isKiwiHub:classified.identifier?.rawValue"
                    + "==KiwiHubSide.panelIdentifier"
            )
        )
    }
}
