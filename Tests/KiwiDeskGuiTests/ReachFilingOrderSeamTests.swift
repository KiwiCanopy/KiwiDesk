import Foundation
import Testing

/// The switch handler FILES a switch only after it carried
/// (#1215). The reach-departure arm is open exactly while the
/// display's filed Space is the one the window sits on, and a
/// bound Desktop's apply runs a full reconcile inside the
/// handler: filed at the top, that sweep found every arm closed
/// and removed the sticky window the carry was about to move
/// (device, 2026-09-21, Desktop 2 bound). No behavior test drives
/// that sweep, so the ORDER is pinned here as spellings: the one
/// call to the filing door follows the carry in the handler's
/// body, the handler body names the store through no other
/// spelling, and the store is reached from three files only. The
/// trade (guard-prover, 2026-09-21): a filing spelled inside a
/// callee the handler runs before the carry, or a per-display
/// subscript write inside one of the three files, is invisible
/// here — the call-site census reds a second CALL of the door,
/// never a write a callee makes by hand.
@Suite("The switch is filed after the carry (#1215)")
struct ReachFilingOrderSeamTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    private static var handlerBody: String {
        get throws {
            let source = try SourceScan.strippedSource(
                at:
                    core
                    .appendingPathComponent("Profiles")
                    .appendingPathComponent("KiwiCore+Desktops.swift")
            )
            return try #require(
                SourceScan.declarationBody(
                    after: "func handleDesktopChange",
                    in: source
                )
            )
        }
    }

    @Test("handleDesktopChange carries, then files")
    func fileFollowsTheCarry() throws {
        let body = try Self.handlerBody
        let carry = try #require(
            body.range(of: "refreshStickyReach(spaces:")
        )
        let file = try #require(body.range(of: "fileDisplaySpaces(in:"))
        #expect(carry.upperBound < file.lowerBound)
        // The store is reached through the door alone: a
        // subscript or whole-map write here re-files a display
        // ahead of the bound-Desktop sweep.
        #expect(!body.contains("lastDisplaySpaces"))
    }

    @Test("the filing door is called once, from the handler")
    func filingDoorHasOneCaller() throws {
        let needle = "fileDisplaySpaces("
        let sites = try SourceScan.identifierSites(
            of: needle,
            under: Self.core
        )
        // The declaration plus one caller — a callee filing ahead
        // of the carry would be a second call.
        #expect(
            sites.count == 2,
            .init(
                rawValue: "found "
                    + sites.map(\.site).joined(separator: ", ")
            )
        )
        #expect(
            sites.allSatisfy {
                $0.file.lastPathComponent == "KiwiCore+Desktops.swift"
            }
        )
    }

    @Test("the filed reading is reached from three files only")
    func storeHasThreeHomes() throws {
        let sites = try SourceScan.identifierSites(
            of: "lastDisplaySpaces",
            under: Self.core
        )
        let files = Set(sites.map(\.file.lastPathComponent))
        // Declared and seeded, diffed and filed, read by the arm.
        #expect(
            files
                == [
                    "DesktopMemory.swift",
                    "KiwiCore+Desktops.swift",
                    "KiwiCore+StickyReach.swift",
                ],
            .init(rawValue: "found " + files.sorted().joined(separator: ", "))
        )
        let writes = try SourceScan.identifierSites(
            of: "lastDisplaySpaces =",
            under: Self.core
        )
        #expect(
            writes.map(\.file.lastPathComponent).sorted()
                == ["DesktopMemory.swift", "KiwiCore+Desktops.swift"]
        )
    }
}
