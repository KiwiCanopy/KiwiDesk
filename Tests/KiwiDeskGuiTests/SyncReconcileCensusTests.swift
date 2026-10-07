import Foundation
import Testing

/// **Who still reconciles on the main actor** (#1930). The
/// synchronous `reconcile(pid:…)` reads the app's window list
/// on the calling thread, which a slow app turns into a stall;
/// the activation and focus arms take `reconcileOffMain`. Every
/// remaining synchronous caller is in the `allowed` map with its
/// reason, pinned by exact count, so a new event-driven caller
/// has to be ruled here rather than slip in beside them.
@Suite("Synchronous reconcile census (#1930)")
struct SyncReconcileCensusTests {
    /// A call, `self.eventLoop.reconcile(pid:` included; neither
    /// `reconcileOffMain(` nor the declaration matches.
    private static func calls(in source: String) -> Int {
        let body = source.replacingOccurrences(
            of: "func reconcile(",
            with: ""
        )
        let pattern = try! NSRegularExpression(
            pattern: #"(?<![A-Za-z])reconcile\(\s*pid:"#
        )
        return pattern.numberOfMatches(
            in: body,
            range: NSRange(body.startIndex..., in: body)
        )
    }

    /// Files under `Sources/KiwiDeskCore` that may call it.
    private let allowed: [String: Int] = [
        // The off-main door itself: an unobserved app, and the
        // apply of the list read.
        "Events/EventLoop+ReconcileOffMain.swift": 2,
        // Boot's pass (#801/#803); its deferred completion reads
        // off main (#1795).
        "Events/EventLoop+BootScan.swift": 1,
        // The adoption heal (#675).
        "Events/EventLoop+Heal.swift": 2,
        // The Desktop-switch bulk pass (#308).
        "Events/EventLoop+ReconcileAll.swift": 2,
        // The transient re-track and the distrust follow-up
        // (#675, #1157), each on its own scheduled slot.
        "App/KiwiCore+Lifecycle.swift": 2,
        // The tabbed create, and a close the arm deferred, whose
        // removal must precede the successor's focus report
        // (#936); every other close reads off main (#1888).
        "Events/EventLoop+Notifications.swift": 2,
        // A hide or unhide (#913).
        "Events/EventLoop+Apps.swift": 1,
        // The Desktop reaps after a move, a switch, a launch.
        "Commands/KiwiCore+DesktopMove.swift": 1,
        "Commands/KiwiCore+DesktopSwitch.swift": 1,
        "Commands/KiwiCore+LaunchReach.swift": 1,
    ]

    @Test("synchronous reconciles stay inside the census")
    func syncReconcilesAreCensused() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let prefix = root.path + "/"
        var counts: [String: Int] = [:]
        var scanned = 0
        for file in try SourceScan.swiftSources(under: root) {
            scanned += 1
            let source = try SourceScan.strippedSource(at: file)
            let hits = Self.calls(in: source)
            guard hits > 0 else { continue }
            counts[String(file.path.dropFirst(prefix.count))] = hits
        }
        #expect(scanned > 100, "scanned \(scanned) files")
        #expect(
            counts == allowed,
            "census and tree disagree: \(counts)"
        )
    }

    @Test("the needle matches the call shapes it names")
    func needleMatchesItsSubject() {
        #expect(Self.calls(in: "reconcile(pid: pid, app: app)") == 1)
        #expect(Self.calls(in: "reconcile(\n    pid: pid,") == 1)
        #expect(Self.calls(in: "reconcileOffMain(pid: pid)") == 0)
        #expect(Self.calls(in: "x.reconcile(pid: pid)") == 1)
        #expect(Self.calls(in: "func reconcile(\n pid: pid_t,") == 0)
    }
}
