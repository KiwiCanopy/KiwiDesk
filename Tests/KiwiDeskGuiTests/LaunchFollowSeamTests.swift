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
        // The claim at the arrival, and the switch after its
        // retile.
        ("launchFollow.claim(", followFile, 1),
        ("= claimLaunchFollow(", "KiwiCore+Events.swift", 1),
        (
            "payLaunchFollow(window, into: space)",
            "KiwiCore+Events.swift", 1
        ),
        ("followSwitch(to: space, focusing: window)", followFile, 1),
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
            of: "launchFollow.forget()",
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

    /// The switch runs AFTER the arrival retile has filed the
    /// window, so the settle and the reissue deliver it.
    @Test("the launch follow pays after the arrival retile")
    func paidAfterTheArrivalRetile() throws {
        let body = try SourceScan.functionBody(
            of: "handle",
            in: "KiwiCore+Events.swift",
            under: "App"
        )
        let retile = try #require(
            body.range(of: "retile(newlyCreatedWindow:")
        )
        let pay = try #require(body.range(of: "payLaunchFollow("))
        #expect(retile.lowerBound < pay.lowerBound)
    }
}
