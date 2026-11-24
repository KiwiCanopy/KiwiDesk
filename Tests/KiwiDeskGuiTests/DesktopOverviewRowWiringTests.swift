import Foundation
import Testing

@testable import KiwiDesk

/// Core reads the shared-Desktop rows from the live "shared" verdict
/// and the Desktop's own "shown" (#3602): the call site feeds the
/// one `sharedDesktops` reading its screens list from, never a
/// constant. `DesktopOverviewRowTests` holds the builder itself.
@Suite("Desktop overview rows are wired to the live reading (#3602)")
struct DesktopOverviewRowWiringTests {
    @Test("the overview's rows take the shared verdict it lists by")
    func rowsTakeTheSharedVerdict() throws {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDeskCore/App/"
                            + "KiwiCore+DesktopOverview.swift"
                    ),
                encoding: .utf8
            )
        ).split(whereSeparator: \.isWhitespace).joined()
        #expect(source.contains("letshared=sharedDesktops(in:snapshot)"))
        #expect(source.contains("shared:shared),position:"))
        #expect(
            source.contains(
                "rows:DesktopOverview.rows(of:screens,shared:shared,"
                    + "isShown:{Self.isShown($0,in:snapshot)})"
            )
        )
    }
}
