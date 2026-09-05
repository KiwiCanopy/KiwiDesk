import Foundation
import Testing

/// The production wirings of a Desktop move's explicit Space
/// (#1150) that no unit test reaches — the `FollowFocusSeamTests`
/// shape for the sibling ledger.
///
/// `PendingSpaceAssignmentTests` holds what the record DOES and
/// `DesktopMoveSpaceTargetTests` drives record→claim through the
/// dispatch and the fold. What neither can see is a wiring
/// DELETED: the re-key (a native-tab flow no unit fixture builds)
/// leaves every behaviour suite green while a tab switch between
/// the command and the departure drops the name.
///
/// Each needle is pinned by EXACT COUNT and to its file: a second
/// recorder would name a Space nobody pays, and zero of any of
/// them is the defect back.
@Suite("A Desktop move's explicit Space stays wired (#1150)")
struct PendingSpaceSeamTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )
    private static let core = root.appendingPathComponent(
        "Sources/KiwiDeskCore"
    )

    /// needle → the files that may carry it, each exactly once.
    private static let wirings: [(String, [String])] = [
        // The recorder: the hidden route of `fileExplicitly`.
        ("pendingSpace.record(", ["KiwiCore+DesktopMove.swift"]),
        // The claim, at the DEPARTURE the gone handler
        // classifies — downstream of every removal, so the
        // eager departure and the reap's reconcile both reach it.
        ("pendingSpace.claim(", ["KiwiCore+GoneReason.swift"]),
        ("pendingSpace.rekey(", ["KiwiCore+RekeyEvent.swift"]),
    ]

    @Test("each wiring exists exactly once per named file")
    func wiringsAreSingular() throws {
        for (needle, files) in Self.wirings {
            let sites = try SourceScan.identifierSites(
                of: needle,
                under: Self.core
            )
            let found = sites.map(\.file.lastPathComponent)
            #expect(
                sites.count == files.count
                    && Set(found) == Set(files),
                """
                expected `\(needle)` once in each of \
                \(files.joined(separator: ", ")), found \
                \(sites.map(\.site).joined(separator: ", "))
                """
            )
        }
    }
}
