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

    /// Files spelling `needle` anywhere under Core, or under one
    /// of its directories.
    private func sites(
        of needle: String,
        under directory: String? = nil
    ) throws -> Set<String> {
        var found: Set<String> = []
        var scanned = 0
        let root = directory.map { core.appendingPathComponent($0) } ?? core
        for file in try SourceScan.swiftSources(under: root) {
            scanned += 1
            if try SourceScan.strippedSource(at: file).contains(needle) {
                found.insert(file.lastPathComponent)
            }
        }
        #expect(
            scanned >= (directory == nil ? 100 : 20),
            "scanned \(scanned) files under \(directory ?? "Core")"
        )
        return found
    }

    /// The verdict guards `track` with nothing beside it: Orion's
    /// twin reads `AXUnknown` as often as `AXStandardWindow`, and
    /// the subrole condition this once carried let it through as
    /// a float (device, 2026-09-30).
    @Test("track asks the shadow verdict of every window, once")
    func trackAsksTheVerdict() throws {
        let tracking = try SourceScan.functionBody(
            of: "track",
            in: "EventLoop+Tracking.swift",
            under: "Events"
        )
        try #require(!tracking.isEmpty)
        let pattern =
            #"guard\s+shadowVerdict\(element, id: window\.id, "#
            + #"pid: pid\)\s*== \.window\s+else \{ return \}"#
        let verdict = try #require(
            tracking.range(of: pattern, options: .regularExpression),
            "track no longer refuses a shadow before it becomes a tile"
        )
        #expect(
            tracking.components(separatedBy: "shadowVerdict(").count == 2
        )
        // Ahead of the registration, or the shadow is a tile by
        // the time it is refused.
        let registration = try #require(
            tracking.range(of: "elements[pid, default: [:]][window.id]")
        )
        #expect(verdict.upperBound < registration.lowerBound)
        // Unconditional: the guard wrapped in a subrole condition
        // keeps every needle above (guard-prover, 2026-09-30).
        // A wrap spelled without the constant would pass; the
        // subrole is otherwise read here only for the float
        // verdicts, by name.
        #expect(!tracking.contains("kAXStandardWindowSubrole"))
    }

    /// A shadow is never tracked, so its report takes the
    /// untracked branch, settled after the reconcile (#1930).
    @Test("the focus arm drops a shadow's report ahead of its read")
    func focusArmDropsTheShadow() throws {
        let arm = try SourceScan.functionBody(
            of: "handleFocusedWindowChanged",
            in: "EventLoop+FocusReport.swift",
            under: "Events"
        )
        let settle = try SourceScan.functionBody(
            of: "settleFocusReport",
            in: "EventLoop+FocusReport.swift",
            under: "Events"
        )
        try #require(!arm.isEmpty && !settle.isEmpty)
        let tracked = try #require(
            arm.range(of: "elements[pid]?[reported] != nil")
        )
        let deferred = try #require(arm.range(of: "settleFocusReport("))
        #expect(tracked.upperBound < deferred.lowerBound)
        let drop = try #require(
            settle.range(of: "!shadows.holds(reported, pid: pid)")
        )
        let read = try #require(settle.range(of: "requestFocusReport("))
        #expect(drop.upperBound < read.lowerBound)
        // A report is never translated into another window's.
        #expect(!arm.contains("hostOfShadow("))
        #expect(!settle.contains("hostOfShadow("))
    }

    @Test("a reconcile re-asks what it tracks, after its sweep")
    func reconcileReasksAfterTheSweep() throws {
        let reconcile = try SourceScan.functionBody(
            of: "reconcile",
            in: "EventLoop+Reconcile.swift",
            under: "Events"
        )
        try #require(!reconcile.isEmpty)
        #expect(
            reconcile.components(separatedBy: "retireShadows(").count == 2
        )
        let sweep = try #require(
            reconcile.range(
                of: "reconcileTabsAndSweep(",
                options: .backwards
            )
        )
        let retire = try #require(reconcile.range(of: "retireShadows("))
        #expect(sweep.upperBound < retire.lowerBound)
        // The record prune AHEAD of that sweep, which would answer
        // the ex-shadow from a record its host no longer backs.
        let prune = try #require(reconcile.range(of: "shadows.prune("))
        #expect(prune.upperBound < sweep.lowerBound)
        #expect(
            try sites(of: "shadows.prune(") == ["EventLoop+Reconcile.swift"]
        )
    }

    @Test("a shadow is kept out of the tab re-key")
    func tabRekeySkipsShadows() throws {
        let sweep = try SourceScan.functionBody(
            of: "reconcileTabsAndSweep",
            in: "EventLoop+Tabs.swift",
            under: "Events"
        )
        try #require(!sweep.isEmpty)
        let pattern =
            #"appeared: appeared\.filter \{\s*"#
            + #"!shadows\.holds\(\$0\.id, pid: pid\)\s*"#
            + #"\}\.map\(appearedTab\)"#
        #expect(
            sweep.range(of: pattern, options: .regularExpression) != nil
        )
    }

    /// The ownership gates and the float verdicts read the policy
    /// through the one reading that survives a record
    /// LaunchServices loses for a moment. A raw read beside it
    /// detaches a running process, or tiles an accessory app's
    /// float for the length of the gap.
    @Test("a process's policy has one reading")
    func policyHasOneReading() throws {
        #expect(
            try sites(of: "func policy(of pid: pid_t)")
                == ["EventLoop+ProcessIdentity.swift"]
        )
        #expect(
            try sites(of: "policy(of: pid)")
                == [
                    "EventLoop+BootScan.swift",
                    "EventLoop+Notifications.swift",
                    "EventLoop+Reconcile.swift",
                    "EventLoop+WindowPolicy.swift",
                ]
        )
        #expect(
            try sites(of: "?? .prohibited") == [],
            "a missing record is read as prohibited beside the reading"
        )
        // The seam's one caller, by the call and not the argument
        // spelling; the declaration is `var activationPolicy:`.
        #expect(
            try sites(of: "activationPolicy(")
                == ["EventLoop+ProcessIdentity.swift"],
            "the raw policy seam is read beside the reading"
        )
        // An observed process's policy is refreshed by the
        // off-main list read alone, filed through one door: a
        // main-actor read is a LaunchServices round trip per AX
        // notification (#1936).
        #expect(
            try sites(of: "notePolicy(")
                == [
                    "EventLoop+ProcessIdentity.swift",
                    "EventLoop+Reconcile.swift",
                ]
        )
        #expect(
            try source("Events/EventLoop+ReconcileOffMain.swift")
                .contains("let readPolicy = activationPolicy")
        )
        // A record is looked up under `Events/` only where a seam
        // defaults to it — the reading's own, and `appAt`,
        // `isActive`, `appIsHidden`, `AppRef(pid:)`. A raw read
        // beside them is a policy the reading cannot keep. The
        // trade: a raw policy read outside `Events/` passes this
        // census; the Core-wide clauses above catch its two
        // spellings, `activationPolicy(` and `?? .prohibited`.
        #expect(
            try sites(
                of: "NSRunningApplication(processIdentifier:",
                under: "Events"
            ) == ["EventLoop+ProcessIdentity.swift", "EventLoop.swift"]
        )
    }

    /// The announced pid naming a process's app is one reading,
    /// which the focus gate and the #292 preflight both take.
    @Test("an announced pid names an app in one place")
    func announcedPidHasOneReading() throws {
        #expect(
            try sites(of: "areSiblings(")
                == [
                    "EventLoop+FocusReport.swift",
                    "EventLoop+ProcessIdentity.swift",
                ]
        )
        let preflight = try source(
            "Commands/KiwiCore+FocusedCommandGuard.swift"
        )
        #expect(preflight.contains("eventLoop.names(front, appOf: pid)"))
        #expect(!preflight.contains("areSiblings("))
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

    /// The raw focused-window seam is read beside the shadow
    /// mapping alone — `focusedWindowID` and its off-main twin
    /// (#1930); a raw reader elsewhere hands state a shadow id.
    @Test("the raw focused-window seam has one reader")
    func rawFocusedWindowSeamHasOneReader() throws {
        #expect(
            try sites(of: "shadows.focusedWindow")
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
