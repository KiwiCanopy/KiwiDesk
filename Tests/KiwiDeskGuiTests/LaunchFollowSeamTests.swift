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

    /// needle → the file that may carry it.
    private static let wirings: [(String, String)] = [
        // The activation channel, and its one consumer.
        ("onAppActivated(pid)", "EventLoop+Apps.swift"),
        ("self?.noteAppActivation(pid)", "KiwiCore+Bootstrap.swift"),
        // The press read, armed with the other machine seams.
        ("launchFollow.pressAge = {", "KiwiCore+BootSeams.swift"),
        // The debt: owed at a press-caused activation, paid at
        // the ruled window's arrival.
        ("launchFollow.record(", followFile),
        ("launchFollow.claim(", followFile),
        ("payLaunchFollow(arrived:", "KiwiCore+Events.swift"),
        // The fold's one input to the payer.
        (
            "effects.placedByAppRule =",
            "StateCoordinator+WindowCreated.swift"
        ),
    ]

    @Test("each wiring exists exactly once, in its own file")
    func wiringsAreSingular() throws {
        for (needle, file) in Self.wirings {
            let sites = try SourceScan.identifierSites(
                of: needle,
                under: Self.core
            )
            #expect(
                sites.count == 1
                    && sites.allSatisfy {
                        $0.file.lastPathComponent == file
                    },
                """
                expected one `\(needle)` in \(file), found: \
                \(sites.map(\.site).joined(separator: ", "))
                """
            )
        }
    }

    /// Two retires, both load-bearing: every activation (the user
    /// moved on) and the Desktop switch (the windows it reveals
    /// are not a launch's). A third would be a new moment ruled
    /// "not a launch", which is the judgement this rests on.
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
        let report = try #require(body.range(of: "onAppActivated(pid)"))
        let reconcile = try #require(body.range(of: "reconcile("))
        #expect(report.lowerBound < reconcile.lowerBound)
    }
}
