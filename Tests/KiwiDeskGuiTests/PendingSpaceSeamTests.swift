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
        (
            "pendingSpace.record(",
            ["KiwiCore+DesktopMoveSpace.swift"]
        ),
        // The claim, at the DEPARTURE the gone handler
        // classifies — downstream of every removal, so the
        // eager departure and the reap's reconcile both reach it.
        ("pendingSpace.claim(", ["KiwiCore+GoneReason.swift"]),
        ("pendingSpace.rekey(", ["KiwiCore+RekeyEvent.swift"]),
        // The one membership filing (add, float re-anchor, focus
        // stamp, emit) — a third hand copy of that list shipped
        // with its re-anchor missing, and no fixture can see a
        // float cross fake screens, so the WIRING is the guard.
        // The needle is the call shape, which the definition
        // line does not match — it binds the callers' `window`
        // spelling, so it counts these four and a fifth spelled
        // otherwise is not seen; `filingReanchors` below holds
        // the step the copies lost.
        (
            "fileMembership(window, into:",
            [
                "KiwiCore+SpaceCommands.swift",
                "KiwiCore+DesktopMove.swift",
                "KiwiCore+DesktopMoveSpace.swift",
                "KiwiCore+SpaceBarDrop.swift",
            ]
        ),
    ]

    /// The helper's callers are counted above; nothing else pins
    /// that the helper still carries the #444 re-anchor, which no
    /// fixture can see cross fake screens.
    @Test("the one filing re-anchors a float")
    func filingReanchors() throws {
        let file = Self.core.appendingPathComponent(
            "Commands/KiwiCore+SpaceCommands.swift"
        )
        // Comments stripped, so a docstring naming the step
        // cannot satisfy the needle (rule-authoring.md).
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        let filing = SourceScan.declarationBody(
            after: "func fileMembership(",
            in: source
        )
        #expect(filing != nil)
        #expect(filing?.contains("reanchorFloat(") == true)
    }

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

    /// The drop-commit files where the POINTER placed the window,
    /// so neither its gate nor its filing may take
    /// `fileMembership`'s re-anchor — a float crossing fake screens
    /// is invisible to every fixture, so the bodies are the guard
    /// (#1686).
    @Test("the drop-commit relocate never re-anchors")
    func dropCommitNeverReanchors() throws {
        let source = try Self.dragRelocate()
        let gate = try #require(
            SourceScan.declarationBody(
                after: "func relocateAcrossDisplay(",
                in: source
            )
        )
        let filing = try #require(
            SourceScan.declarationBody(
                after: "func commitCrossDisplayDrop(",
                in: source
            )
        )
        #expect(gate.contains("commitCrossDisplayDrop("))
        #expect(filing.contains("insertDropped("))
        for body in [gate, filing] {
            #expect(!body.contains("reanchorFloat("))
            #expect(!body.contains("fileMembership("))
        }
    }

    /// The drop re-file writes its flag past every gate, then takes
    /// the drop-commit's filing and nothing that re-anchors or
    /// warps beside it (#1686).
    @Test("the drop re-file takes the drop-commit alone")
    func dropRefileTakesTheDropCommit() throws {
        let body = try #require(
            SourceScan.declarationBody(
                after: "func relocateDroppedFloat(",
                in: try Self.dragRelocate()
            )
        )
        #expect(
            body.components(separatedBy: "commitCrossDisplayDrop(")
                .count == 2
        )
        let routes = [
            "fileMembership(", "reanchorFloat(", "moveWindow(",
            "relocateAcrossDisplay(",
        ]
        for route in routes {
            #expect(!body.contains(route), "\(route)")
        }
    }

    private static func dragRelocate() throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: core.appendingPathComponent(
                    "Tiling/KiwiCore+DragRelocate.swift"
                ),
                encoding: .utf8
            )
        )
    }
}
