import Foundation
import Testing

/// The #2002 delayed-close debt's one-home shape, the fourth of
/// the #951/#958/#1532 family (state-and-layout.md): one writer
/// file, one call site per door, and the Space switch inside the
/// close-return tail's raise branch alone. Behaviour is
/// `DelayedCloseReturnTests`'; these are the wiring clauses no
/// fixture can red on.
@Suite("Delayed-close debt seams (#2002)")
struct DelayedCloseSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let core = root.appendingPathComponent(
        "Sources/KiwiDeskCore"
    )
    private static let home = "KiwiCore+DelayedCloseReturn.swift"

    private func files(of needle: String) throws -> [String] {
        try SourceScan.identifierSites(of: needle, under: Self.core)
            .map(\.file.lastPathComponent)
    }

    private func source(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(path)
        )
    }

    @Test("the debt is stored on the core and written in one file")
    func oneWriter() throws {
        let found = Set(try files(of: "delayedCloseDebt"))
        #expect(found == [Self.home, "KiwiCore.swift"], "\(found)")
    }

    /// Each door's definition and its one production call site
    /// (the retire door also runs inside the note).
    @Test("each door has its one call site")
    func oneSitePerDoor() throws {
        let h = Self.home
        let doors: [(String, [String])] = [
            ("noteDelayedClose(", [h, "KiwiCore+FocusEvents.swift"]),
            (
                "noteDelayedCloseFollowed(",
                [h, "KiwiCore+SpaceCommands.swift"]
            ),
            ("healDelayedClose(", [h, "KiwiCore+CloseReturn.swift"]),
            (
                "retireDelayedClose(",
                [
                    h, h, "KiwiCore+Bootstrap.swift",
                    "KiwiCore+RekeyEvent.swift",
                ]
            ),
            (
                "delayedCloseOpened(",
                [h, "EventLoop+RemovalDistrust.swift"]
            ),
            // The episode's re-list end, which retires the debt.
            (
                "endRemovalEpisodes(",
                [
                    "EventLoop+RemovalDistrust.swift",
                    "EventLoop+Tabs.swift",
                ]
            ),
        ]
        for (door, sites) in doors {
            let found = try files(of: door).sorted()
            #expect(found == sites.sorted(), "\(door): \(found)")
        }
    }

    /// The note runs on the HONORED path, after the report is
    /// remembered; the follow mark at the follow's landing.
    @Test("the note and the follow mark sit where they are ruled")
    func notePlacement() throws {
        let handler = try source("App/KiwiCore+FocusEvents.swift")
        let honored = try #require(
            handler.range(of: "rememberHonoredFocus(id)")
        )
        let note = try #require(handler.range(of: "noteDelayedClose("))
        #expect(honored.lowerBound < note.lowerBound)
        let follow = try SourceScan.functionBody(
            of: "landFocusFollow",
            in: "KiwiCore+SpaceCommands.swift",
            under: "Commands"
        )
        #expect(follow.contains("noteDelayedCloseFollowed(id)"))
    }

    /// The heal changes facts only: the switch is the tail's, on
    /// the raise branch after the stand-down verdict, and the
    /// switch is the one follow-shaped `followSwitch`, whose retile
    /// places the Space and lifts its floats (#11, #412).
    @Test("the owed switch is the tail's raise branch alone")
    func switchInTheRaiseBranch() throws {
        let heal = try source("App/" + Self.home)
        for spelling in [
            "applyFocusedSpaceSwitch(", "followSwitch(", "focusWindow(",
            "workspaces.activate(",
        ] {
            #expect(!heal.contains(spelling), "\(spelling)")
        }
        let tail = try source("App/KiwiCore+CloseReturn.swift")
        #expect(!tail.contains("applyFocusedSpaceSwitch("))
        #expect(tail.components(separatedBy: "followSwitch(").count == 2)
        let verdict = try #require(
            tail.range(of: "!closeReturnRaiseStandsDown")
        )
        let owedSwitch = try #require(
            tail.range(of: "followSwitch(to: owedSpace, focusing: next)")
        )
        let restack = try #require(tail.range(of: "armCloseReturnRestack("))
        #expect(verdict.lowerBound < owedSwitch.lowerBound)
        #expect(owedSwitch.lowerBound < restack.lowerBound)
    }
}
