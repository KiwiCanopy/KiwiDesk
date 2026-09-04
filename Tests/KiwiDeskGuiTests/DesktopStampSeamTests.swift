import Foundation
import Testing

/// The Desktop stamp WRITE stays behind its seam (#1147): the
/// bridge call is reached through `DesktopMemory.writeStamp`,
/// which both `makeTestCore` twins pin to a refusal.
///
/// Why the pin, and not just the seam: a fixture space id IS a
/// real Desktop id on the host — Desktop 1 is id 1 — and the
/// write is one macOS PERSISTS, so an unpinned suite that boots a
/// core would leave a KiwiDesk identity on the developer's own
/// Desktop and nothing would say so (tests.md ▸ machine touch).
/// `MachineTouchTests` holds the twins identical, which makes a
/// pin dropped from ONE of them red; only this pins that the pin
/// exists at all.
@Suite("The Desktop stamp write stays behind its seam (#1147)")
struct DesktopStampSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let tests = root.appendingPathComponent("Tests")
    /// Spelled in two halves so this file is not its own hit.
    private static let pin =
        "desktopMemory.writeStamp = " + "{ _, _ in false }"

    @Test("makeTestCore refuses the stamp write")
    func testCorePinsTheWrite() throws {
        let twins = ["KiwiDeskCoreTests", "KiwiDeskGuiTests"].map {
            Self.tests.appendingPathComponent("\($0)/TestCore.swift")
        }
        for twin in twins {
            let source = try SourceScan.strippedSource(at: twin)
            #expect(
                source.contains(Self.pin),
                .init(
                    rawValue:
                        "\(twin.lastPathComponent) does not pin "
                        + "the stamp write"
                )
            )
        }
    }

    /// The live writer is the production default and nothing
    /// else: a caller naming it directly would write to the host
    /// from a suite that pinned the seam.
    @Test("the live writer is named only where it is defaulted")
    func liveWriterIsOnlyTheDefault() throws {
        let sites = try SourceScan.identifierSites(
            of: "KiwiCore." + "liveStampWrite",
            under: Self.root.appendingPathComponent("Sources")
        )
        #expect(
            sites.count == 1
                && sites.first?.file.lastPathComponent
                    == "DesktopMemory.swift",
            .init(
                rawValue: "found "
                    + sites.map(\.site).joined(separator: ", ")
            )
        )
    }
}
