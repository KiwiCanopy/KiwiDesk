import Foundation
import Testing

@testable import KiwiDeskCore

/// #1230's call sites, pinned beside the behaviour rather than
/// instead of it — where the Desktop→Space memory is WRITTEN,
/// and the pairings a cross-space move owes.
///
/// `DesktopSpacePersistenceTests` proves the write does the right
/// thing when called; it cannot see the call being deleted,
/// because it calls `persistDesktopSpaceMemory()` itself. That
/// gap is the whole risk here: the eight ordinary sidecar
/// writers are user actions, so a forgotten call site does not
/// fail anything — it silently returns the feature to "persists
/// only if you happen to save something afterwards", which is
/// what it did before this lane and what no assertion notices.
/// The same two-sided shape `UpdaterSeamGuardTests` takes, and
/// for the same stated reason (tests.md ▸ the inverted seam).
@Suite("#1230 call sites")
struct ProfileSpacesWiringTests {
    private var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    private func body(
        of declaration: String,
        in file: String
    ) throws -> String? {
        let url = coreRoot.appendingPathComponent(file)
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        return SourceScan.declarationBody(
            after: declaration,
            in: source
        )
    }

    /// QUIT. The session file written beside it carries only the
    /// CURRENT Desktop's Spaces, so every other Desktop's windows
    /// are filed at the next boot from this map alone.
    @Test("stop() writes the Desktop memory")
    func stopWritesTheMemory() throws {
        let stop = try body(
            of: "func stop()",
            in: "App/KiwiCore+Lifecycle.swift"
        )
        #expect(stop != nil)
        #expect(
            stop?.contains("persistDesktopSpaceMemory()") == true,
            """
            stop() no longer writes the Desktop→Space memory, so \
            it reaches disk only when some unrelated save follows \
            the last Desktop switch.
            """
        )
    }

    /// THE DISCARD. Without the write, a quit right after
    /// "Discard Saved Window Arrangement" re-adopts the map at
    /// the next boot — the one record here that outlives the
    /// process.
    @Test("The discard writes the cleared memory")
    func discardWritesTheClearedMemory() throws {
        let discard = try body(
            of: "func discardSavedArrangement()",
            in: "App/KiwiCore+Reset.swift"
        )
        #expect(discard != nil)
        #expect(
            discard?.contains("forgetDesktopSpaceMemory()") == true
        )
        #expect(
            discard?.contains("persistDesktopSpaceMemory()")
                == true,
            """
            the discard clears the map in memory but not in the \
            file, so the next boot adopts it back.
            """
        )
    }

    /// THE RESTORE. Every sidecar write stamps the live map in,
    /// so the discard must precede the write or the DESTINATION's
    /// memory lands in the file the reload then adopts.
    @Test("The restore discards before it writes")
    func restoreDiscardsBeforeWriting() throws {
        let url = coreRoot.appendingPathComponent(
            "App/KiwiCore+BackupRestore.swift"
        )
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        guard
            let discard = source.range(
                of: "discardSavedArrangement()"
            ),
            let write = source.range(of: "try writeIncoming(")
        else {
            Issue.record("the restore no longer does both")
            return
        }
        #expect(
            discard.lowerBound < write.lowerBound,
            """
            the restore writes before it discards, so the write's \
            stamp carries the destination's Desktop memory into \
            the file the reload adopts.
            """
        )
    }

    /// A cross-space move owes the #444 re-anchor, which
    /// `pruneSpaces` makes twenty lines away and every other
    /// move site makes too — membership alone never moves a
    /// float, since no layout frame is computed for one.
    ///
    /// Pinned as WIRING because the effect is not reachable in
    /// a fixture: `reanchorFloat` reads `NSScreen` and
    /// `GeometryUtils.axVisibleFrame`, so asserting the
    /// translated frame would assert the host’s own screens
    /// (tests.md ▸ pin the display).
    @Test("The restore re-anchors the floats it moves")
    func restoreReanchorsFloats() throws {
        let restore = try body(
            of: "func restorePartitioning",
            in: "Profiles/KiwiCore+ProfileSpaces.swift"
        )
        #expect(restore != nil)
        #expect(
            restore?.contains("reanchorFloat(") == true,
            Comment(
                rawValue:
                    "a float restored into a Space on another "
                    + "screen keeps the previous screen's "
                    + "coordinates"
            )
        )
        #expect(
            restore?.contains("restoreFocusTrackers(") == true,
            Comment(
                rawValue:
                    "`add` nils the focus trackers when it moves "
                    + "the focused window; the restore must put "
                    + "them back"
            )
        )
    }
}
