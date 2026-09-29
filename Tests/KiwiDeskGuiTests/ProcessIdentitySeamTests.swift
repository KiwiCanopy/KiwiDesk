import Foundation
import Testing

/// The #1785 call sites no behavior test can reach: each is a live
/// AX or LaunchServices read on a real process, and the suites that
/// drive the decisions (`ProcessIdentityTests`, `ShadowWindowTests`)
/// call the decisions directly, so a call site that stopped routing
/// through them would leave every one green. Lives in the GUI target
/// because `SourceScan` does.
@Suite("Process identity seams (#1785)")
struct ProcessIdentitySeamTests {
    private var core: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    private func source(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: core.appendingPathComponent(path)
        )
    }

    /// Files spelling `needle` anywhere under Core.
    private func sites(of needle: String) throws -> Set<String> {
        var found: Set<String> = []
        var scanned = 0
        for file in try SourceScan.swiftSources(under: core) {
            scanned += 1
            if try SourceScan.strippedSource(at: file).contains(needle) {
                found.insert(file.lastPathComponent)
            }
        }
        #expect(scanned >= 100, "scanned \(scanned) Core files")
        return found
    }

    @Test("track asks the shadow verdict of a standard window")
    func trackAsksTheVerdict() throws {
        let tracking = try source("Events/EventLoop+Tracking.swift")
        let pattern =
            #"subrole == kAXStandardWindowSubrole,\s*"#
            + #"shadowVerdict\(element, id: window\.id, pid: pid\)"#
            + #"\s*!= \.window\s*\{\s*return"#
        #expect(
            tracking.range(of: pattern, options: .regularExpression)
                != nil,
            "track no longer refuses a shadow before it becomes a tile"
        )
    }

    @Test("the focus report names a shadow's host")
    func focusReportMapsTheShadow() throws {
        let report = try source("Events/EventLoop+FocusReport.swift")
        #expect(report.contains("let id = hostOfShadow(reported, pid: pid)"))
    }

    /// The AX focused-window read lives in ONE resolver, which maps
    /// a shadow to its host; a fifth reader beside it would hand a
    /// shadow id to state as a focus.
    @Test("the AX focused-window read has one home")
    func focusedWindowReadHasOneHome() throws {
        #expect(
            try sites(of: "AXHelper.focusedWindow(")
                == ["EventLoop+ShadowWindows.swift"]
        )
    }

    /// LaunchServices' frontmost app is read in ONE place; its pid
    /// is -1 for a child registration, so a raw read beside the
    /// chain refuses the second profile's commands again.
    @Test("the frontmost app has one reader")
    func frontmostAppHasOneReader() throws {
        #expect(
            try sites(of: "frontmostApplication")
                == ["EventLoop+ProcessIdentity.swift"]
        )
    }

    /// Every pass that attaches apps reads `liveApps`; the raw list
    /// has no entry for an unlisted process. `ReconcileAll` keeps
    /// the raw read for its pre-start branch alone.
    @Test("the raw running-app list has its two readers")
    func rawListHasItsReaders() throws {
        #expect(
            try sites(of: "runningApplications()")
                == [
                    "EventLoop+ProcessIdentity.swift",
                    "EventLoop+ReconcileAll.swift",
                ]
        )
        let all = try source("Events/EventLoop+ReconcileAll.swift")
        #expect(
            all.contains(
                "isRunning ? liveApps() : runningApplications()"
            )
        )
    }
}
