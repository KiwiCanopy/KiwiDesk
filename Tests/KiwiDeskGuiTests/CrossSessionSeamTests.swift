import Foundation
import Testing

/// The seams the cross-session restore leans on (#1385), held over
/// Core's comment-stripped source: every membership add is
/// classified (a user filing must stamp the match through the one
/// seam, or the title pass may undo it), the restore policy has
/// one caller, and every window-removal arm reports its departure
/// to the logout rollback. The census sees `workspaces.add(` only:
/// an order primitive inside `withSpace { … }` is review's.
@Suite("Cross-session seams (#1385)")
struct CrossSessionSeamTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    /// File → (count, kind) of `workspaces.add(` call sites. A
    /// `user` site is the one stamping seam; every other kind is
    /// not a user filing and must not need the stamp.
    static let adds: [String: (Int, String)] = [
        "KiwiCore+SpaceCommands.swift":
            (2, "user — addFocusedToSpace, the one stamping seam"),
        "StateCoordinator+WindowCreated.swift":
            (3, "fold — an arrival's placement"),
        "StateSnapshot.swift": (1, "restore — the replay's adopt"),
        "KiwiCore+DragCrossing.swift":
            (1, "cancel — a crossing put back where it began"),
        "KiwiCore+ProfileSpaces.swift":
            (2, "bulk — a profile's Spaces re-filed"),
        "KiwiCore+HeldSpaces.swift":
            (1, "bulk — a held Space sent home"),
    ]

    private func counts(of needle: String) throws -> [String: Int] {
        var found: [String: Int] = [:]
        for url in try SourceScan.swiftSources(under: Self.core) {
            let text = try SourceScan.strippedSource(at: url)
            let n = text.occurrences(of: needle)
            if n > 0 { found[url.lastPathComponent] = n }
        }
        return found
    }

    @Test("every membership add is classified, and users stamp once")
    func membershipAddsAreClassified() throws {
        let found = try counts(of: "workspaces.add(")
        #expect(found == Self.adds.mapValues(\.0))
        let stamps = try counts(of: "stampUserFiling(")
        #expect(
            stamps == [
                "KiwiCore+SpaceCommands.swift": 1,
                "StateCoordinator+SpaceMemory.swift": 1,
            ]
        )
        let body = try SourceScan.functionBody(
            of: "addFocusedToSpace",
            in: "KiwiCore+SpaceCommands.swift",
            under: "Commands"
        )
        #expect(body.contains("if !restoring { state.stampUserFiling("))
    }

    @Test("the restore policy has one caller, the title pass")
    func restoringHasOneCaller() throws {
        let found = try counts(of: "restoring: true")
        #expect(found == ["KiwiCore+CrossSession.swift": 1])
    }

    /// Each removal arm reaches the rollback's ledger: the gone
    /// handler (destroys), the hide arm and an app's exit.
    @Test("every window-removal arm reports its departure")
    func removalArmsReportDepartures() throws {
        let found = try counts(of: "crash.noteDeparture(")
        #expect(
            found == [
                "KiwiCore+GoneReason.swift": 1,
                "KiwiCore+Events.swift": 1,
                "KiwiCore+PreFold.swift": 1,
            ]
        )
        func source(_ path: String) throws -> String {
            try SourceScan.strippedSource(
                at: Self.core.appendingPathComponent(path)
            )
        }
        let events = try source("App/KiwiCore+Events.swift")
        let gone = try SourceScan.functionBody(
            of: "handleWindowGone",
            in: "KiwiCore+GoneReason.swift",
            under: "App"
        )
        #expect(gone.contains("crash.noteDeparture("))
        let exit = try SourceScan.functionBody(
            of: "prepareAppExit",
            in: "KiwiCore+PreFold.swift",
            under: "App"
        )
        #expect(exit.contains("crash.noteDeparture(closed: true)"))
        let hide = try #require(events.range(of: "case .windowHidden"))
        let next = try #require(
            events.range(
                of: "case .",
                range: hide.upperBound..<events.endIndex
            )
        )
        #expect(
            events[hide.upperBound..<next.lowerBound]
                .contains("crash.noteDeparture(closed: false)")
        )
        #expect(events.contains("prepareAppExit(pid)"))
        #expect(events.contains("goneReason = handleWindowGone("))
    }
}
