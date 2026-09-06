import Foundation
import Testing

/// The own-window press stamps click provenance (#1281), and
/// only that. What no fixture can see: the local arm fires on
/// real input alone, and the two boot wirings are closures
/// nothing but `start()` runs. Three shapes are pinned —
/// `onOwnWindowLeftMouseDown` fired INLINE from the local
/// `.leftMouseDown` arm (ahead of the enqueued store, because
/// our own window's AX report reaches the run loop before a
/// queued Task would), the two boot closures taking the ONE
/// stamp, and the own-window closure taking nothing else — so
/// the display follow keeps its bar-overlay exemption (#446).
@Suite("Own-window click provenance stays wired (#1281)")
struct OwnPressProvenanceSeamTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")
    private static let tracker = core.appendingPathComponent(
        "Events/MouseTracker.swift"
    )
    private static let boot = core.appendingPathComponent(
        "App/KiwiCore+BootSeams.swift"
    )

    @Test("The local down arm fires provenance inline, once")
    func localArmFiresInline() throws {
        let source = try SourceScan.strippedSource(at: Self.tracker)
        #expect(source.occurrences(of: "onOwnWindowLeftMouseDown?(") == 1)
        let start = try #require(
            SourceScan.declarationBody(
                after: "func start()",
                in: source
            )
        )
        // The first local installation is the down arm; its
        // closure is the balanced body after the call.
        let arm = try #require(
            SourceScan.declarationBody(
                after: "addLocalMonitorForEvents",
                in: start
            )
        )
        // That installation is the DOWN arm: its argument list
        // names the event.
        let install = try #require(
            start.range(of: "addLocalMonitorForEvents")
        )
        let args = try #require(
            SourceScan.callArguments(
                of: "addLocalMonitorForEvents(",
                in: String(start[install.lowerBound...])
            )
        )
        #expect(args.contains(".leftMouseDown"))
        let fire = try #require(
            arm.range(of: "onOwnWindowLeftMouseDown?(")
        )
        let store = try #require(arm.range(of: "Task {"))
        #expect(fire.upperBound <= store.lowerBound)
        #expect(!arm.contains("onLeftMouseDown?("))
    }

    @Test("Both boot arms take the one stamp; the own arm nothing else")
    func bootArmsTakeTheOneStamp() throws {
        let source = try SourceScan.strippedSource(at: Self.boot)
        #expect(source.occurrences(of: "stampLeftClick(") == 2)
        #expect(source.occurrences(of: "onOwnWindowLeftMouseDown = ") == 1)
        let own = try #require(
            SourceScan.declarationBody(
                after: "onOwnWindowLeftMouseDown = ",
                in: source
            )
        )
        #expect(own.contains("stampLeftClick("))
        #expect(!own.contains("followDisplayUnderClick("))
        let other = try #require(
            SourceScan.declarationBody(
                after: "onLeftMouseDown = ",
                in: source
            )
        )
        #expect(other.contains("stampLeftClick("))
        #expect(other.contains("followDisplayUnderClick("))
    }

    /// `lastLeftClick` has one writer in production, the stamp:
    /// a second assignment would carry a press without the
    /// press-time resolution `clickReachedWindow` argues for.
    @Test("The provenance ledger has one production writer")
    func oneWriter() throws {
        var writers: [String] = []
        for file in try SourceScan.swiftSources(under: Self.core) {
            let text = try SourceScan.strippedSource(at: file)
            let count = text.occurrences(of: "lastLeftClick = ")
            if count > 0 {
                writers.append("\(file.lastPathComponent):\(count)")
            }
        }
        #expect(
            writers == ["KiwiCore+ClickProvenance.swift:1"],
            "found \(writers)"
        )
    }
}
