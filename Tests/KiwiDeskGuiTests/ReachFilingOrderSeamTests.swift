import Foundation
import Testing

/// The switch handler FILES a switch only after it carried
/// (#1215). The reach-departure arm is open exactly while the
/// display's filed Space is the one the window sits on, and a
/// bound Desktop's apply runs a full reconcile inside the
/// handler: filed at the top, that sweep found every arm closed
/// and removed the sticky window the carry was about to move
/// (device, 2026-09-21, Desktop 2 bound). No behavior test drives
/// that sweep, so the ORDER is pinned here — the write after the
/// carry, and one writer beside the boot seed.
@Suite("The switch is filed after the carry (#1215)")
struct ReachFilingOrderSeamTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    @Test("handleDesktopChange carries, then files")
    func fileFollowsTheCarry() throws {
        let source = try SourceScan.strippedSource(
            at: Self.core
                .appendingPathComponent("Profiles")
                .appendingPathComponent("KiwiCore+Desktops.swift")
        )
        let body = try #require(
            SourceScan.declarationBody(
                after: "func handleDesktopChange",
                in: source
            )
        )
        let carry = try #require(
            body.range(of: "refreshStickyReach(spaces:")
        )
        let file = try #require(body.range(of: "fileDisplaySpaces(in:"))
        #expect(carry.upperBound < file.lowerBound)
        // Filed once per switch: one call in the handler.
        let calls = body.components(separatedBy: "fileDisplaySpaces(in:")
        #expect(calls.count == 2)
    }

    @Test("the filed reading has one writer beside the boot seed")
    func oneWriterBesideTheSeed() throws {
        let sites = try SourceScan.identifierSites(
            of: "lastDisplaySpaces =",
            under: Self.core
        )
        #expect(
            sites.map(\.file.lastPathComponent).sorted()
                == ["DesktopMemory.swift", "KiwiCore+Desktops.swift"],
            .init(
                rawValue: "found "
                    + sites.map(\.site).joined(separator: ", ")
            )
        )
    }
}
