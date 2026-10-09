import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Counts every way a bridge WRITE could be built or dispatched:
/// each write operation's initialiser, and the dispatch selector.
/// A read-only run that touched one would count here.
private final class WriteTripwire: NSObject {
    nonisolated(unsafe) static var touched = 0

    @objc(initWithWindows:spaceID:)
    init(windows: NSArray, spaceID: UInt64) {
        Self.touched += 1
    }

    @objc(initWithWindows:spaces:)
    init(windows: NSArray, spaces: NSArray) { Self.touched += 1 }

    @objc(initWithDisplayIdentifier:spaceID:)
    init(displayIdentifier: NSString, spaceID: UInt64) {
        Self.touched += 1
    }

    @objc(initWithSpaces:)
    init(spaces: NSArray) { Self.touched += 1 }

    @objc(initWithOptions:values:)
    init(options: UInt32, values: NSDictionary) { Self.touched += 1 }

    @objc(initWithSpaceID:)
    init(spaceID: UInt64) { Self.touched += 1 }

    @objc(initWithSpaceID:name:)
    init(spaceID: UInt64, name: NSString) { Self.touched += 1 }

    @objc(initWithSpaceID:values:)
    init(spaceID: UInt64, values: NSDictionary) { Self.touched += 1 }

    @objc func performWithWMBridgeDelegate() -> AnyObject? {
        Self.touched += 1
        return nil
    }
}

/// Stands in for every bridge READ: answers each read initialiser
/// and dispatches to nil, counting the dispatch.
private final class ReadStub: NSObject {
    nonisolated(unsafe) static var performed = 0

    override init() {}

    @objc(initWithSpaceID:)
    init(spaceID: UInt64) {}

    @objc(initWithOptions:windows:)
    init(options: UInt32, windows: NSArray) {}

    @objc func performWithWMBridgeDelegate() -> AnyObject? {
        Self.performed += 1
        return nil
    }
}

/// `self_test` (#1889): a verdict per private path, read-only.
/// Serialized because the bridge's resolver seam is process-global.
@Suite("self_test probes the private paths read-only", .serialized)
@MainActor
struct PrivatePathSelfTestTests {
    private func run(_ probes: [PrivatePathProbe]) -> [String: JSONValue] {
        guard
            case .object(let reply) = PrivatePathSelfTest.report(
                probes,
                macOS: "test"
            )
        else { return [:] }
        return reply
    }

    private func verdicts(_ reply: [String: JSONValue]) -> [String] {
        guard case .array(let rows)? = reply["probes"] else { return [] }
        return rows.compactMap { row in
            guard case .object(let fields) = row else { return nil }
            return fields["verdict"]?.stringValue
        }
    }

    @Test("an absent path is never verified, and says what runs")
    func absentSkipsTheRead() {
        var asked = 0
        let probe = PrivatePathProbe.read(
            "SLSFake",
            home: "SkyLight",
            resolved: { false },
            verify: {
                asked += 1
                return .works("read")
            }
        )
        let reply = run([probe])
        #expect(verdicts(reply) == ["absent"])
        #expect(asked == 0)
        #expect(
            PrivatePathSelfTest.detail(of: .absent, .symbol)
                .contains("fallback")
        )
        #expect(
            PrivatePathSelfTest.detail(of: .absent, .bridgeClass)
                .contains("capability is absent")
        )
    }

    @Test("the report keeps the catalog's order and counts each label")
    func reportOrdersAndCounts() {
        let probes: [PrivatePathProbe] = [
            .read("A", home: "H", resolved: { true }) { .works("ok") },
            .read("A2", home: "H", resolved: { true }) {
                .answered("live")
            },
            .write("B", home: "H", resolved: { true }),
            .write("C", home: "H", resolved: { false }),
            .read("D", home: "H", resolved: { true }) { .failed("x") },
            .read("E", home: "H", resolved: { true }) {
                .inconclusive("y")
            },
        ]
        let reply = run(probes)
        #expect(
            verdicts(reply)
                == [
                    "works", "answered", "resolved", "absent", "failed",
                    "inconclusive",
                ]
        )
        guard case .object(let counts)? = reply["counts"] else {
            Issue.record("no counts")
            return
        }
        for label in PrivatePathVerdict.labels {
            #expect(counts[label] == .number(1), "\(label)")
        }
    }

    @Test("a nil bridge class reads as the capability absent")
    func absentBridgeClasses() {
        WMBridge.classResolverOverride = { _ in nil }
        defer { WMBridge.classResolverOverride = nil }
        let bridge = PrivatePathSelfTest.catalog(.empty)
            .filter { $0.kind == .bridgeClass }
        #expect(bridge.count == WMBridge.Operation.allCases.count)
        #expect(Set(verdicts(run(bridge))) == ["absent"])
    }

    /// The operations that only read, stated apart from `isRead`
    /// so a write relabelled as a read is caught rather than
    /// trusted: a new operation is a write until listed here.
    private static let reads: Set<String> = [
        "CopyManagedDisplaySpacesOperation",
        "SpaceCopyNameOperation",
        "SpaceCopyValuesOperation",
        "CopySpacesForWindowsOperation",
    ]

    @Test("only the listed reads are classed as reads")
    func readRosterIsPinned() {
        let classed = WMBridge.Operation.allCases
            .filter(\.isRead).map(\.rawValue)
        #expect(Set(classed) == Self.reads)
    }

    /// Every read's `verify` RUNS — reads resolve to a stub that
    /// answers nil, the context shows an own window, the active
    /// Space is pinned — so a write called from inside a read's
    /// verification trips the wire too.
    @Test("the read-only run never builds or dispatches a write")
    func writesAreNeverDispatched() {
        WriteTripwire.touched = 0
        ReadStub.performed = 0
        WMBridge.classResolverOverride = { name in
            Self.reads.contains(name)
                ? ReadStub.self : WriteTripwire.self
        }
        NativeSpaces.activeSpaceIDOverride = 5
        defer {
            WMBridge.classResolverOverride = nil
            NativeSpaces.activeSpaceIDOverride = nil
        }
        let context = PrivatePathContext(
            ownWindow: {
                PrivatePathContext.OwnWindow(
                    id: 7,
                    bounds: CGRect(x: 0, y: 0, width: 10, height: 10)
                )
            },
            census: { nil },
            spaceOfWindow: { _ in .hosted(5) }
        )
        let bridge = PrivatePathSelfTest.catalog(context)
            .filter { $0.kind == .bridgeClass }
        let reply = run(bridge)
        let writes = WMBridge.Operation.allCases.filter {
            !Self.reads.contains($0.rawValue)
        }
        #expect(!writes.isEmpty)
        #expect(
            verdicts(reply).filter { $0 == "resolved" }.count
                == writes.count
        )
        // Non-vacuous: every read was dispatched and verified.
        #expect(ReadStub.performed == Self.reads.count)
        #expect(WriteTripwire.touched == 0)
    }

    @Test("self_test answers through the dispatcher")
    func dispatchesTheReport() {
        WMBridge.classResolverOverride = { _ in nil }
        defer { WMBridge.classResolverOverride = nil }
        let response = makeTestCore().execute(PrivatePathSelfTest.command)
        guard case .object(let reply)? = response.data else {
            Issue.record("no report: \(response.error ?? "")")
            return
        }
        let found = verdicts(reply)
        #expect(found.count == PrivatePathSelfTest.catalog(.empty).count)
        #expect(Set(found).isSubset(of: PrivatePathVerdict.labels))
    }
}
