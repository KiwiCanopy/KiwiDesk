import Foundation
import Testing

/// The frame applier's echo grace is measured on an injected
/// clock, and every core a suite builds freezes it (#1456) —
/// tests.md ▸ a test that reads an age-bounded ledger pins the
/// clock. `TravelerRehomeConsumerTests` redded on CI when a
/// starved runner put more than the grace between a retile's
/// stamp and the read that asked for it.
///
/// Two clauses, the `MouseButtonSeamGuardTests` shape. The host
/// uptime is read only where a closure seam DEFAULTS to it —
/// `FrameApplier.clock`, `PlacementLedger.live` (#1161),
/// `ZOrderDrain.now`'s and `TeardownRestack.now`'s live
/// wiring — never inside a ledger,
/// so a new bound in either tree reds here until it takes a
/// seam of its own; counted per file, since a total stays green
/// when a read migrates between homes. And both `makeTestCore`
/// twins pin the freeze, since deleting it from both is
/// invisible to the twins-identical scan and green on every fast
/// run, which is the run the defect hides in.
///
/// The `Date`-stamped ledgers take the core's `wallClock` (#1852):
/// every `Date()` left in Core is counted per file against a
/// register naming why it stays, so a new ledger reds until it is
/// classified. Residue: a ledger growing its own clock as
/// `CACurrentMediaTime()` or `DispatchTime.now()` is not this
/// needle's, and a pin re-written equivalently (`{ 0.0 }`) reads
/// as missing, fail-closed.
@Suite("The echo grace runs on an injected clock")
struct EchoClockSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let productionTrees = [
        root.appendingPathComponent("Sources/KiwiDeskCore"),
        root.appendingPathComponent("Sources/KiwiDesk"),
    ]

    /// Every file that may read the host uptime, with its count:
    /// each site is a closure seam's live default.
    private static let allowed: [String: Int] = [
        "FrameApplier.swift": 1,
        "PlacementLedger.swift": 1,
        "KiwiCore+ZOrderFloats.swift": 1,
        "KiwiCore+TeardownRaise.swift": 2,
        "KiwiCore+InPlaceRestart.swift": 1,
        "BootNoticeController.swift": 1,
        // `BarPeek.now`, the hover peek's cool-down clock (#1946).
        "BarPeek.swift": 1,
    ]

    @Test("the host uptime is read only as a seam's default")
    func uptimeIsReadOnlyBehindASeam() throws {
        var counts: [String: Int] = [:]
        for tree in Self.productionTrees {
            for file in try SourceScan.swiftSources(under: tree) {
                let hits = try SourceScan.strippedSource(at: file)
                    .occurrences(of: "systemUptime")
                if hits > 0 {
                    counts[file.lastPathComponent, default: 0] += hits
                }
            }
        }
        for (file, expected) in Self.allowed {
            let found = counts[file] ?? 0
            #expect(
                counts[file] == expected,
                "\(file) reads uptime \(found)× (pinned \(expected))"
            )
        }
        let strays = counts.keys.filter { Self.allowed[$0] == nil }
        #expect(
            strays.isEmpty,
            "uptime read outside a seam default: \(strays.sorted())"
        )
        // The applier's one read IS the seam's default.
        let applier = Self.root.appendingPathComponent(
            "Sources/KiwiDeskCore/Tiling/FrameApplier.swift"
        )
        #expect(
            try SourceScan.strippedSource(at: applier).contains(
                "var clock: @Sendable () -> TimeInterval = {"
            )
        )
        // The placement ledger's clock takes no default, so a
        // fresh ledger names its clock; `live` is its one read.
        let ledger = Self.root.appendingPathComponent(
            "Sources/KiwiDeskCore/Tiling/PlacementLedger.swift"
        )
        let ledgerSource = try SourceScan.strippedSource(at: ledger)
        #expect(ledgerSource.contains("var clock: () -> TimeInterval\n"))
        #expect(
            ledgerSource.contains(
                "init(clock: @escaping () -> TimeInterval) {"
            )
        )
        #expect(
            ledgerSource.contains(
                "PlacementLedger { ProcessInfo.processInfo.systemUptime }"
            )
        )
    }

    @Test("a test resets the placement ledger, never builds one")
    func testsKeepTheFrozenLedger() throws {
        // A fresh ledger in a suite takes whatever clock it is
        // handed — `live` puts the host uptime back — so resets go
        // through `forgetAll`; the ledger's own suite is the one
        // builder, and this file spells the needles.
        let trees = SourceScan.targetTrees(
            under: Self.root.appendingPathComponent("Tests")
        )
        let sites = try [
            "PlacementLedger(", "PlacementLedger {",
            "PlacementLedger.live",
        ]
        .flatMap { needle in
            try trees.flatMap {
                try SourceScan.identifierSites(of: needle, under: $0)
            }
        }
        let exempt: Set = [
            "PlacementLedgerTests.swift", "EchoClockSeamTests.swift",
        ]
        let strays = sites.filter {
            !exempt.contains($0.file.lastPathComponent)
        }
        #expect(!sites.isEmpty)
        #expect(
            strays.isEmpty,
            .init(rawValue: strays.map(\.site).joined(separator: ", "))
        )
    }

    @Test("makeTestCore freezes the clock in both twins")
    func testCoreFreezesTheClock() throws {
        let twins = ["KiwiDeskCoreTests", "KiwiDeskGuiTests"]
            .map {
                Self.root.appendingPathComponent(
                    "Tests/\($0)/TestCore.swift"
                )
            }
        for twin in twins {
            let source = try SourceScan.strippedSource(at: twin)
            let target = twin.deletingLastPathComponent()
                .lastPathComponent
            for pin in [
                "core.tiler.applier.clock = { 0 }",
                "core.tiler.placements.clock = { 0 }",
                "core.wallClock = { frozen }",
            ] {
                let pins = source.occurrences(of: pin)
                #expect(pins == 1, "\(target) pins `\(pin)` \(pins)×")
            }
        }
    }

    /// The files whose ledgers stamp and age on `wallClock`.
    private static let wallClockHomes = [
        "App/KiwiCore+AccessibilityReturn.swift",
        "App/KiwiCore+ClickProvenance.swift",
        "App/KiwiCore+Events.swift",
        "App/KiwiCore+FocusEvents.swift",
        "App/KiwiCore+MouseWarp.swift",
        "Commands/KiwiCore+FocusRaise.swift",
        "Commands/KiwiCore+ZOrderFloats.swift",
    ]

    /// Every file that still reads the wall clock in Core, with its
    /// count. `param` — a `now:` parameter's default, the caller
    /// threading the clock; `seam` — a closure seam's default;
    /// `stamp` — a timestamp no ledger ages; `debt` — a ledger not
    /// yet on `wallClock`, to move when it is next touched.
    private static let wallClockReads: [String: Int] = [
        "CrashRecovery.swift": 1,  // seam
        "LogExport.swift": 2,  // param
        "PendingSpaceAssignment.swift": 2,  // param
        "FollowFocusIntent.swift": 3,  // param
        "LaunchFollowIntent.swift": 1,  // param
        "KiwiCore+LaunchFollow.swift": 3,  // param
        "MoveIntentLatch.swift": 2,  // param
        "KiwiCore+DesktopSettle.swift": 1,  // param
        "EventLoop+Tabs.swift": 1,  // param
        "KiwiCore+GoneReason.swift": 3,  // param ×2, debt
        "KiwiCore+WakeFocus.swift": 2,  // param, debt
        "KiwiCore+Teardown.swift": 2,  // stamp: a 1 s spin deadline
        "SleepWakeManager.swift": 1,  // stamp: a snapshot's age
        "MouseTracker.swift": 3,  // stamp: the press record
        "EventLoop+Apps.swift": 1,  // debt
        "KiwiCore+DesktopMove.swift": 1,  // debt: lastDesktopSwitch
        "KiwiCore+DesktopSwitch.swift": 1,  // debt: lastDesktopSwitch
        "KiwiCore+Desktops.swift": 1,  // debt: lastDesktopSwitch
        "KiwiCore+DisplayFocus.swift": 1,  // debt: lastDesktopSwitch
        "KiwiCore+SpaceCommands.swift": 1,  // debt: lastDesktopSwitch
        "KiwiCore+SpaceFocusHandoff.swift": 2,  // debt
        "KiwiCore+StickyReach.swift": 3,  // debt
        "KiwiCore+UnsolicitedResize.swift": 1,  // debt
        "KiwiCore+MouseResizeEnd.swift": 1,  // debt
        "TilingEngine+SizeBounds.swift": 2,  // debt
    ]

    @Test("the wall clock is read only where the register says")
    func wallClockReadsAreClassified() throws {
        let core = Self.root.appendingPathComponent(
            "Sources/KiwiDeskCore"
        )
        var counts: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: core) {
            let source = try SourceScan.strippedSource(at: file)
            // Every spelling of "now" a ledger could grow (#1021).
            let hits = ["Date()", "Date.now", "Date(timeIntervalSinceNow"]
                .reduce(0) { $0 + source.occurrences(of: $1) }
            if hits > 0 {
                counts[file.lastPathComponent, default: 0] += hits
            }
        }
        for (file, expected) in Self.wallClockReads {
            let found = counts[file] ?? 0
            #expect(
                found == expected,
                "\(file) reads the wall clock \(found)× (pinned \(expected))"
            )
        }
        let strays = counts.keys.filter {
            Self.wallClockReads[$0] == nil
        }
        #expect(
            strays.isEmpty,
            "wall clock read beside `wallClock`: \(strays.sorted())"
        )
        for home in Self.wallClockHomes {
            let source = try SourceScan.strippedSource(
                at: core.appendingPathComponent(home)
            )
            #expect(
                source.occurrences(of: "wallClock()") > 0,
                "\(home) no longer reads `wallClock`"
            )
        }
        let seam = try SourceScan.strippedSource(
            at: core.appendingPathComponent("App/KiwiCore.swift")
        )
        #expect(
            seam.occurrences(of: "var wallClock: () -> Date = Date.init")
                == 1
        )
    }
}
