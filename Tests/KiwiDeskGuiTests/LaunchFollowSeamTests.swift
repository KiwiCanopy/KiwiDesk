import Foundation
import Testing

/// The production wirings of the launch follow (#1599) and its
/// unowed arm (#2478) that no unit test reaches — the
/// `FollowFocusSeamTests` shape.
///
/// `LaunchFollowTests` drives the core entry, the fold and the
/// arrival arm, but it calls `noteAppActivation` and injects the
/// press read itself, so the activation channel, the machine
/// read and the Desktop switch's retire are invisible to it.
/// Both seams default INERT — the callback a no-op, the press
/// read nil — so a deleted wiring silently turns the feature off
/// with every suite green, which is tests.md's inverted-seam
/// case: each needle is pinned by EXACT count and to its file.
@Suite("The launch follow stays wired (#1599)")
struct LaunchFollowSeamTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )
    private static let core = root.appendingPathComponent(
        "Sources/KiwiDeskCore"
    )
    private static let followFile = "KiwiCore+LaunchFollow.swift"

    /// needle → the one file that carries it, and how often.
    private static let wirings: [(String, String, Int)] = [
        // The activation channel, and its one consumer.
        ("onAppActivated(", "EventLoop+Apps.swift", 1),
        (
            "self?.noteAppActivation(activation)",
            "KiwiCore+Bootstrap.swift", 1
        ),
        // The press read, armed with the other machine seams.
        (
            "launchFollow.pressAge = { KiwiCore.secondsSinceUserPress() }",
            "KiwiCore+BootSeams.swift", 1
        ),
        // Since when that read is KiwiDesk's: unwired, a cold
        // start never follows (#2201).
        (
            "launchFollow.watchedFor = {",
            "KiwiCore+BootSeams.swift", 1
        ),
        ("launchFollow.pressBefore(", followFile, 1),
        // The ONE door that owes, and its owers: the activation
        // judged a launch, Open or Focus's launch and pull
        // branches, New Window (#1518), and Jump to window's
        // un-minimize, an open by the same rule (#1875).
        ("launchFollow.record(", followFile, 1),
        ("oweLaunchFollow(bundleID, at: now)", followFile, 1),
        ("oweLaunchFollow(bundleID)", "KiwiCore+Launch.swift", 2),
        ("oweLaunchFollow(bundle)", "KiwiCore+WindowActions.swift", 1),
        ("oweLaunchFollow(unminimized)", "KiwiCore+JumpActions.swift", 1),
        // The claim at the arrival, the switch in place of its
        // retile, and the arrival's #45 start-at-target carried
        // into the switch's own pass.
        (
            "newlyCreatedWindow: newcomer",
            "KiwiCore+SpaceTransition.swift", 1
        ),
        ("launchFollow.claim(", followFile, 1),
        ("= claimLaunchFollow(", "KiwiCore+Events.swift", 1),
        ("payLaunchFollow($0.0, into: $0.1)", "KiwiCore+Events.swift", 1),
        (
            "followSwitch(to: space, focusing: window, arriving: true)",
            followFile, 1
        ),
        // A window landing before its app's activation (a reopen,
        // an un-minimize): noted at the arrival, paid at the
        // activation, as a whole switch.
        ("launchFollow.notePlacement(", followFile, 1),
        ("launchFollow.takePlacement(", followFile, 1),
        (
            "followSwitch(to: placed.space, focusing: placed.window)",
            followFile, 1
        ),
        // The fold's one input to the payer.
        (
            "effects.placedByAppRule =",
            "StateCoordinator+WindowCreated.swift", 1
        ),
        // The unowed arm (#2478): the process age armed with the
        // other machine seams, the create ledger fed and opened
        // by the WindowServer route and closed by `stop()`, the
        // verdict at the claim, and a late create paid as a
        // whole switch. Each defaults closed, so a deleted line
        // turns the arm off with every behaviour suite green.
        (
            "launchFollow.processAge = {",
            "KiwiCore+BootSeams.swift", 1
        ),
        (
            "ProcessIdentity.startAge(of: pid, now: $0.wallClock())",
            "KiwiCore+BootSeams.swift", 1
        ),
        (
            "windowCreates.isLive = active",
            "KiwiCore+WindowServerWakeUp.swift", 1
        ),
        (
            "windowCreates.isLive = false",
            "KiwiCore+Lifecycle.swift", 1
        ),
        (
            "windowCreates.noteCreated(id, at: wallClock())",
            "KiwiCore+WindowServerWakeUp.swift", 1
        ),
        (
            "windowCreates.noteDestroyed(id)",
            "KiwiCore+WindowServerWakeUp.swift", 1
        ),
        // A late create resolves through the arrival door (#2630).
        (
            "resolveArrivalCreated(id)",
            "KiwiCore+WindowServerWakeUp.swift", 1
        ),
        ("payLateSpawnFollow(id)", "KiwiCore+ArrivalProvenance.swift", 1),
        (
            "deferred.schedule(.arrivalCreated",
            "KiwiCore+ArrivalProvenance.swift", 1
        ),
        ("launchFollow.dropSpawn()", "KiwiCore+Lifecycle.swift", 1),
        ("spawnVerdict(window, provenance: provenance)", followFile, 1),
        ("launchFollow.noteSpawn(", followFile, 1),
        ("launchFollow.takeSpawn(", followFile, 1),
        ("followSwitch(to: spawn.space, focusing: id)", followFile, 1),
    ]

    @Test("each wiring exists exactly as often as pinned, in its file")
    func wiringsArePinned() throws {
        for (needle, file, count) in Self.wirings {
            let sites = try SourceScan.identifierSites(
                of: needle,
                under: Self.core
            )
            #expect(
                sites.count == count
                    && sites.allSatisfy {
                        $0.file.lastPathComponent == file
                    },
                """
                expected \(count)× `\(needle)` in \(file), found: \
                \(sites.map(\.site).joined(separator: ", "))
                """
            )
        }
    }

    /// The ledger has one feeder, the WindowServer route (#2478):
    /// a second would make an adoption read as a creation.
    @Test("the create ledger is fed from the WindowServer route alone")
    func ledgerHasOneFeeder() throws {
        let sites = try SourceScan.identifierSites(
            of: "windowCreates.noteCreated(",
            under: Self.core
        )
        #expect(
            sites.count == 1
                && sites.first?.file.lastPathComponent
                    == "KiwiCore+WindowServerWakeUp.swift",
            "found: \(sites.map(\.site))"
        )
    }

    /// The late payment runs a whole switch, so it leaves the
    /// event-port drain the notify proc runs inside — which the
    /// border pump waits on — through the deferred hop (#2478).
    @Test("a late create pays outside the event-port drain")
    func latePaymentLeavesTheDrain() throws {
        let body = try SourceScan.functionBody(
            of: "resolveArrivalCreated",
            in: "KiwiCore+ArrivalProvenance.swift",
            under: "App"
        )
        let hop = try #require(
            body.range(of: "deferred.schedule(.arrivalCreated")
        )
        let settle = try #require(body.range(of: "settleArrival("))
        let expire = try #require(
            body.range(of: "resolveExpiredArrivals(")
        )
        #expect(hop.lowerBound < settle.lowerBound)
        #expect(hop.lowerBound < expire.lowerBound)
        // Nothing settles inside the drain, ahead of the hop.
        #expect(body.components(separatedBy: "settleArrival(").count == 2)
        #expect(!body.contains("emitWindowCreated("))
    }

    /// Four retires, each load-bearing: another app's activation
    /// (the user moved on), the Desktop switch (the windows it
    /// reveals are not a launch's), a refused New Window, which
    /// opened nothing (#1518), and a Pocket key's claim, whose
    /// window stays where the user is (#2612). A fourth would be a new moment
    /// ruled "not a launch", which is the judgement this rests on.
    @Test("the debt is retired by an activation, a switch, a refusal")
    func twoRetires() throws {
        let sites = try SourceScan.identifierSites(
            of: "launchFollow.forget(",
            under: Self.core
        )
        #expect(
            Set(sites.map(\.file.lastPathComponent))
                == [
                    Self.followFile, "KiwiCore+Desktops.swift",
                    "KiwiCore+WindowActions.swift",
                    "KiwiCore+PocketClaim.swift",
                ]
                && sites.count == 4,
            "found: \(sites.map(\.site))"
        )
    }

    /// The activation's own reconciles adopt a window the app
    /// shows on activating; the debt must be owed before them.
    @Test("the activation is reported ahead of its reconciles")
    func reportedBeforeReconcile() throws {
        let body = try SourceScan.functionBody(
            of: "appActivated",
            in: "EventLoop+Apps.swift",
            under: "Events"
        )
        let report = try #require(body.range(of: "onAppActivated("))
        let reconcile = try #require(
            body.range(of: "reconcileOffMain(")
        )
        #expect(report.lowerBound < reconcile.lowerBound)
    }

    /// The switch REPLACES the arrival's event retile: run after
    /// it, that retile parks the new window in its still-hidden
    /// Space for the switch to bring back — a visible double move.
    @Test("the launch follow pays in place of the arrival retile")
    func paidInPlaceOfTheArrivalRetile() throws {
        let body = try SourceScan.functionBody(
            of: "handle",
            in: "KiwiCore+Events.swift",
            under: "App"
        )
        let pay = try #require(body.range(of: "payLaunchFollow("))
        let gate = try #require(
            body.range(of: "if willRetile, followed != true {")
        )
        let retile = try #require(
            body.range(of: "retile(newlyCreatedWindow:")
        )
        #expect(pay.lowerBound < gate.lowerBound)
        #expect(gate.lowerBound < retile.lowerBound)
    }
}
