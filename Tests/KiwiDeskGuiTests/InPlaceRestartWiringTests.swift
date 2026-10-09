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
        #expect(
            stop.contains("shutdownCleanly(inPlace: inPlace, captured:")
        )
    }

    /// The update half (#930 ruling 1): Sparkle's relaunch
    /// delegate call reaches the core through the one hook, and
    /// the app wires the hook to the announcement. A delegate
    /// method Sparkle stops calling, or a hook left at its no-op
    /// default, gathers every update — invisible to any suite.
    @Test("Sparkle's relaunch announces an in-place restart")
    func sparkleRelaunchIsWired() throws {
        let observer = try body(
            of: #"func updaterWillRelaunchApplication\(_ updater: "#
                + #"SPUUpdater\) \{"#,
            in: "Sources/KiwiDesk/Updates/UpdateState.swift"
        )
        #expect(observer.contains("onWillRelaunch()"))
        let live = try body(
            of: #"var onWillRelaunch: \(\) -> Void \{\n"#,
            in: "Sources/KiwiDesk/Updates/AppUpdater.swift"
        )
        #expect(live.contains("observer.onWillRelaunch = newValue"))
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/AppDelegate.swift")
        let delegate = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        let wiring =
            #"updater\.onWillRelaunch = \{[^}]*"#
            + #"core\.announceUpdateRelaunch\(\)"#
        #expect(
            delegate.range(of: wiring, options: .regularExpression)
                != nil,
            "the app no longer announces Sparkle's relaunch to Core"
        )
    }

    /// `cliOnlyIsNeverLua` reads the command table; Lua also
    /// registers functions by hand, which it cannot see. A config
    /// calling the announcement would turn its next Quit into an
    /// in-place restart.
    @Test("no Lua file registers the announcement by hand")
    func luaNeverSpellsTheAnnouncement() throws {
        let lua = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore/Lua")
        let files = try SourceScan.swiftSources(under: lua)
        try #require(!files.isEmpty)
        for file in files {
            let text = try SourceScan.strippedSource(at: file)
            for spelling in [
                "prepare_restart", "prepareRestartCommand",
                "prepareServiceRestart", "announceUpdateRelaunch",
            ] {
                #expect(
                    !text.contains(spelling),
                    "\(file.lastPathComponent) spells \(spelling)"
                )
            }
        }
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
