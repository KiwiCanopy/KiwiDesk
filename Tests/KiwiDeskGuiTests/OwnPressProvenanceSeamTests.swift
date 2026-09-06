import Foundation
import Testing

/// The press fan-out hears both arms and carries the origin
/// (#1281). What no fixture can see: the arms fire on real input
/// alone, and the boot wiring is a closure only `start()` runs.
/// Pinned: the local `.leftMouseDown` arm delivers INLINE, with no
/// enqueueing spelling between the arm's start and the delivery
/// (an enqueued job's order against our own window's AX report is
/// not guaranteed); the global arm delivers too; the one boot
/// closure takes the one `stampLeftClick` unconditionally and
/// gates the display follow on `.otherApp` (#446); and
/// `lastLeftClick` has one production writer.
///
/// Disclosed limit: the inline clause refuses the enqueueing
/// spellings it names; a new one is invisible to it.
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
    private static let enqueuers = [
        "Task", "DispatchQueue", "async", "detached", "perform(",
    ]

    /// The balanced closure body of the local down arm — the
    /// first local installation in `start()`, whose argument
    /// list names the event.
    private static func localDownArm() throws -> String {
        let source = try SourceScan.strippedSource(at: tracker)
        let start = try #require(
            SourceScan.declarationBody(
                after: "func start()",
                in: source
            )
        )
        let install = try #require(
            start.range(of: "addLocalMonitorForEvents(")
        )
        let tail = String(start[install.lowerBound...])
        let args = try #require(
            SourceScan.callArguments(
                of: "addLocalMonitorForEvents(",
                in: tail
            )
        )
        #expect(args.contains(".leftMouseDown"))
        return try #require(
            SourceScan.declarationBody(
                after: "addLocalMonitorForEvents(",
                in: tail
            )
        )
    }

    @Test("The local down arm delivers inline, before its store")
    func localArmDeliversInline() throws {
        let arm = try Self.localDownArm()
        let fire = try #require(
            arm.range(of: "deliverPress(")
        )
        let store = try #require(arm.range(of: "recordDown("))
        #expect(fire.upperBound <= store.lowerBound)
        let before = String(arm[..<fire.lowerBound])
        for spelling in Self.enqueuers {
            #expect(
                !before.contains(spelling),
                "the local delivery is enqueued through `\(spelling)`"
            )
        }
    }

    @Test("Both arms deliver through the one fan-out")
    func bothArmsDeliver() throws {
        let source = try SourceScan.strippedSource(at: Self.tracker)
        #expect(source.occurrences(of: "deliverPress(") == 3)
        #expect(source.occurrences(of: "from: .otherApp") >= 1)
        #expect(source.occurrences(of: "from: .ownWindow") >= 1)
        let deliver = try #require(
            SourceScan.declarationBody(
                after: "func deliverPress(",
                in: source
            )
        )
        #expect(deliver.contains("onLeftMouseDown?(location, origin)"))
        let record = try #require(
            SourceScan.declarationBody(
                after: "func recordDown(",
                in: source
            )
        )
        #expect(!record.contains("onLeftMouseDown"))
    }

    @Test("The boot closure stamps unconditionally, follows on origin")
    func bootClosureStampsAndGates() throws {
        let source = try SourceScan.strippedSource(at: Self.boot)
        #expect(source.occurrences(of: "onLeftMouseDown = ") == 1)
        #expect(source.occurrences(of: "stampLeftClick(") == 1)
        #expect(source.occurrences(of: "followDisplayUnderClick(") == 1)
        let closure = try #require(
            SourceScan.declarationBody(
                after: "onLeftMouseDown = ",
                in: source
            )
        )
        let stamp = try #require(closure.range(of: "stampLeftClick("))
        let gate = try #require(
            closure.range(of: "if origin == .otherApp")
        )
        #expect(stamp.upperBound <= gate.lowerBound)
        let gated = try #require(
            SourceScan.declarationBody(
                after: "if origin == .otherApp",
                in: closure
            )
        )
        #expect(gated.contains("followDisplayUnderClick("))
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
