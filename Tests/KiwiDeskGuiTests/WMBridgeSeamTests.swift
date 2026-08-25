import Foundation
import Testing

/// Every call into SkyLight's window-management bridge goes
/// through `WMBridge` (os-private-apis.md): the class-name
/// prefix `SLSBridged` and the dispatch selector
/// `performWithWMBridgeDelegate` are each spelled ONCE, in the
/// wrapper's core file, and nowhere else in either source tree.
///
/// Why a scan and not a type: the bridge is reached by string —
/// `NSClassFromString` and a selector — so nothing in the
/// compiler stops a second caller from spelling a class name in
/// full beside its own call site, and that caller would skip
/// the nil-degradation contract, the resolver seam tests inject
/// through, and the "performed is not applied" reading the
/// wrapper's doc carries (#889). The wrapper joins the prefix to
/// short operation names at lookup precisely so that a full
/// class name anywhere else is a hit.
///
/// **The lens, not the list** (`ResourceBundleRoutingTests`):
/// exact per-file counts, so an unlisted use fails on arrival
/// and a removed listed one fails too.
@Suite("WMBridge seam")
struct WMBridgeSeamTests {
    private var sourceRoots: [URL] {
        let sources = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
        let entries = try? FileManager.default
            .contentsOfDirectory(
                at: sources,
                includingPropertiesForKeys: [.isDirectoryKey]
            )
        return (entries ?? []).filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?
                .isDirectory == true
        }
    }

    /// The needles and, per needle, every file allowed to carry
    /// it with today's exact count. This map is the exemption
    /// list; the rule file points here rather than restating it.
    private let allowed: [String: [String: Int]] = [
        "SLSBridged": ["KiwiDeskCore/OS/WMBridge.swift": 1],
        "performWithWMBridgeDelegate": [
            "KiwiDeskCore/OS/WMBridge.swift": 1
        ],
        "NSClassFromString": ["KiwiDeskCore/OS/WMBridge.swift": 1],
    ]

    @Test(
        "The bridge's strings live only in the wrapper",
        arguments: [
            "SLSBridged", "performWithWMBridgeDelegate",
            "NSClassFromString",
        ]
    )
    func bridgeStringsStayInsideTheWrapper(needle: String) throws {
        let expected = try #require(allowed[needle])
        var counts: [String: Int] = [:]
        for root in sourceRoots {
            let prefix = root.deletingLastPathComponent().path + "/"
            for file in try SourceScan.swiftSources(under: root) {
                let source = SourceScan.stripComments(
                    try String(contentsOf: file, encoding: .utf8)
                )
                let hits = source.occurrences(of: needle)
                guard hits > 0 else { continue }
                let key = String(file.path.dropFirst(prefix.count))
                counts[key, default: 0] += hits
            }
        }
        for (path, found) in counts.sorted(by: { $0.key < $1.key }) {
            #expect(
                expected[path] == found,
                """
                \(path) spells `\(needle)` \(found)x, allowed \
                \(expected[path].map(String.init) ?? "0"). Reach \
                the bridge through WMBridge, which resolves the \
                class at runtime and degrades to nil when it is \
                absent.
                """
            )
        }
        for (path, count) in expected where counts[path] == nil {
            #expect(
                count == 0,
                """
                \(path) no longer spells `\(needle)` — drop its \
                entry so the guard keeps biting.
                """
            )
        }
    }
}
