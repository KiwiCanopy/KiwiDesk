import Foundation
import Testing

/// The Desktop switch batch's wirings no unit test reaches
/// (#2347): the settle and the switch's event park behind the
/// batch, bootstrap pays the held bars from its fold, a switch
/// reveal claims no launch follow, and a per-app read the batch
/// awaits is held for it. Each deleted line leaves the behaviour
/// suites green, so each is pinned by exact count to its file.
@Suite("Switch reconcile wirings (#2347)")
struct SwitchReconcileSeamTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    /// needle → (the file that carries it, how often).
    private static let wirings: [(String, String, Int)] = [
        (
            "self?.eventLoop.settleAfterSwitchReads {",
            "KiwiCore+DesktopSettle.swift", 1
        ),
        (
            "eventLoop.switchReads.onApplied = {",
            "KiwiCore+Bootstrap.swift", 1
        ),
        // The one door that holds a refresh.
        (
            "guard !holdingForSwitch || !eventLoop.switchReads.isPending",
            "KiwiCore+Shelf.swift", 1
        ),
        // A shelf stand-down for a fullscreen arrival passes the
        // hold, on the main arm and the secondary one.
        (
            "updateBars(holdingForSwitch: false)",
            "KiwiCore+Desktops.swift", 1
        ),
        (
            "updateBars(holdingForSwitch: snapshot.showsUserSpaces(changed))",
            "KiwiCore+Desktops.swift", 1
        ),
        // The switch's public event waits for its arrivals.
        (
            "eventLoop.afterSwitchReads {",
            "KiwiCore+DesktopEvents.swift", 1
        ),
        // A switch reveal never claims a launch's follow (#1599).
        (
            "guard !eventLoop.switchReads.applying,",
            "KiwiCore+LaunchFollow.swift", 1
        ),
        // A per-app read the batch awaits is held for the fold.
        (
            "if switchReads.holdsApply(pid) {",
            "EventLoop+ReconcileOffMain.swift", 1
        ),
    ]

    @Test("each wiring exists exactly once, in its own file")
    func wiringsAreSingular() throws {
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
                expected \(count) `\(needle)` in \(file), found: \
                \(sites.map(\.site).joined(separator: ", "))
                """
            )
        }
    }

    @Test("the settle body runs inside the parked closure")
    func settleBodyIsParked() throws {
        let source = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "Profiles/KiwiCore+DesktopSettle.swift"
            )
        )
        let body = try #require(
            SourceScan.declarationBody(
                after: "func settleAfterDesktopSwitch(",
                in: source
            )
        )
        let park = try #require(
            body.range(of: "settleAfterSwitchReads {")
        )
        let settle = try #require(body.range(of: "desktopSettle(ifStill:"))
        #expect(park.upperBound < settle.lowerBound)
        #expect(
            body.components(separatedBy: "desktopSettle(ifStill:").count
                == 2,
            "a second, unparked settle call"
        )
    }
}
