import Foundation
import Testing

/// The in-place restart's wiring (#930) that no behavior suite
/// reaches: `stop()` gathers only in its not-announced branch,
/// `service restart` announces before its bootout and only for a
/// loaded service while `service stop` announces nothing — launchd
/// and a live teardown are not test-drivable. Brace-anchored
/// needles over comment-stripped source (`StartupSweepWiringTests`
/// states the known limits of the shape).
@Suite("In-place restart wiring (#930)")
struct InPlaceRestartWiringTests {
    private func body(
        of signature: String,
        in path: String,
        indent: String = "    "
    ) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(path)
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        try #require(!text.isEmpty)
        let pattern = signature + #"[\s\S]{0,6000}?\n"# + indent + #"\}"#
        return String(
            text[
                try #require(
                    text.range(of: pattern, options: .regularExpression)
                )
            ]
        )
    }

    @Test("stop gathers only when no in-place restart was taken")
    func stopGathersOnlyInItsElseBranch() throws {
        let stop = try body(
            of: #"public func stop\(\) \{"#,
            in: "Sources/KiwiDeskCore/App/KiwiCore+Lifecycle.swift"
        )
        #expect(stop.contains("let inPlace = takeInPlaceRestart()"))
        #expect(
            stop.occurrences(of: "gatherWindows()") == 1,
            "stop() gathers from more than one place"
        )
        let branch =
            #"if inPlace \{[^{}]*\} else \{\s*gatherWindows\(\)\s*\}"#
        #expect(
            stop.range(of: branch, options: .regularExpression) != nil,
            """
            gatherWindows() is no longer the else branch of \
            `if inPlace` — an in-place restart must gather \
            nothing, parked windows included (#930 ruling 2).
            """
        )
        #expect(stop.contains("shutdownCleanly(inPlace: inPlace)"))
    }

    @Test("service restart announces before its bootout, when loaded")
    func restartAnnouncesFirst() throws {
        let path = "Sources/KiwiDeskCore/Service/ServiceManager.swift"
        let restart = try body(
            of: #"public static func restart\(\) -> Outcome \{"#,
            in: path
        )
        let announce = try #require(
            restart.range(of: "if wasLoaded { announceInPlaceRestart() }")
        )
        let bootout = try #require(restart.range(of: "\"bootout\""))
        #expect(announce.upperBound <= bootout.lowerBound)
        let stop = try body(
            of: #"public static func stop\(\) -> Outcome \{"#,
            in: path
        )
        #expect(
            !stop.contains("announceInPlaceRestart"),
            "service stop must gather: it is no restart (#930)"
        )
    }
}
