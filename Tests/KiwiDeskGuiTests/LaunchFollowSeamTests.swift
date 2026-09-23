import Foundation
import Testing

/// The production wirings of the launch follow (#1599) that no
/// unit test reaches — the `FollowFocusSeamTests` shape.
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
        // The ONE door that owes, and its two owers: the
        // activation judged a launch, and Open or Focus's launch
        // and pull branches.
        ("launchFollow.record(", followFile, 1),
        ("oweLaunchFollow(bundleID, at: now)", followFile, 1),
        ("oweLaunchFollow(bundleID)", "KiwiCore+Launch.swift", 2),
        // The claim at the arrival, the switch in place of its
        // retile, and the arrival's #45 start-at-target carried
        // into the switch's own pass.
        (
            "newlyCreatedWindow: newcomer,",
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

    /// Two retires, both load-bearing: another app's activation
    /// (the user moved on) and the Desktop switch (the windows it
    /// reveals are not a launch's). A third would be a new moment
    /// ruled "not a launch", which is the judgement this rests on.
    @Test("the debt is retired by an activation and a Desktop switch")
    func twoRetires() throws {
        let sites = try SourceScan.identifierSites(
            of: "launchFollow.forget(",
            under: Self.core
        )
        #expect(
            Set(sites.map(\.file.lastPathComponent))
                == [Self.followFile, "KiwiCore+Desktops.swift"]
                && sites.count == 2,
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
        let reconcile = try #require(body.range(of: "reconcile("))
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
