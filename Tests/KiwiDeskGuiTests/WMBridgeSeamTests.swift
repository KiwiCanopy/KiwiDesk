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
///
/// The fourth needle, `WMBridge.`, pins every READER of the
/// wrapper in `Sources/` by exact count, so a consumer that
/// reads the bridge inside a view `body` or a second model is a
/// hit and a GUI suite rendering that view cannot reach the live
/// bridge through it unseen. The map's SHAPE is the rule it
/// enforces: availability is read once, by
/// `KiwiCore.canDriveDesktops`, which is what a GUI gate
/// consumes; any other entry may name only the operations it
/// dispatches.
///
/// The second test looks the other way, at the test trees: a
/// suite reaches `WMBridge` only through `classResolverOverride`
/// (`tests.md`, #565). Under `swift test` the harness is
/// AppKit-deaf, so a bare read answers a uniform false and
/// `isAvailable` caches it for the process — the available
/// branch is unreachable without the seam, and a suite that
/// believes it tested it has tested the deaf one. This file is excluded from
/// that scan by path — its `allowed` map spells the wrapper's
/// file name, which carries the needle — and the exclusion is
/// asserted, so a checkout where the path comparison stopped
/// matching reds rather than counting this file as compliant.
@Suite("WMBridge seam")
struct WMBridgeSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let testTrees = SourceScan.targetTrees(
        under: root.appendingPathComponent("Tests")
    )

    private var sourceRoots: [URL] {
        SourceScan.targetTrees(
            under: Self.root.appendingPathComponent("Sources")
        )
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
        // The bridge's consumers (#884), by role: the
        // capability predicate `canDriveDesktops` is the ONE
        // reader of availability — a GUI gate consumes that,
        // never the bridge — and a verb reads only the
        // operations it dispatches.
        "WMBridge.": [
            "KiwiDeskCore/App/KiwiCore+Accessors.swift": 1,
            "KiwiDeskCore/Commands/KiwiCore+DesktopMove.swift": 1,
            "KiwiDeskCore/Commands/KiwiCore+DesktopSwitch.swift": 2,
            // #1145 sticky reach: the one carry MOVE.
            "KiwiDeskCore/App/KiwiCore+StickyReach.swift": 1,
        ],
    ]

    @Test(
        "The bridge's strings live only in the wrapper",
        arguments: [
            "SLSBridged", "performWithWMBridgeDelegate",
            "NSClassFromString", "WMBridge.",
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

    /// Scanner files whose only `WMBridge.` spellings are the
    /// scan strings they match production against — this file,
    /// the needle itself. The stated trade (rule-authoring.md):
    /// an exempt file gaining a REAL bridge call goes unseen
    /// here, so an entry may name only a suite that reads source
    /// rather than driving a core. `scanExemptEntriesAreLive`
    /// keeps each entry honest: a renamed or needle-free file
    /// reds rather than exempting nothing.
    private static let scanExempt: Set<String> = [
        "WMBridgeSeamTests.swift"
    ]

    /// The exemption's own liveness — replacing the vacuous
    /// `!reached.contains(self)` a path-keyed exclusion once
    /// carried: every exempt entry must name a file that exists
    /// in the test trees AND spells the needle, or the entry is
    /// exempting nothing and reds here.
    @Test("every scan exemption names a live needle-bearing file")
    func scanExemptEntriesAreLive() throws {
        for name in Self.scanExempt {
            var found = false
            for tree in Self.testTrees {
                for file in try SourceScan.swiftSources(
                    under: tree
                )
                where file.lastPathComponent == name {
                    found = true
                    let source = try String(
                        contentsOf: file,
                        encoding: .utf8
                    )
                    #expect(
                        source.contains("WMBridge."),
                        Comment(
                            rawValue:
                                "\(name) no longer spells the "
                                + "needle — drop its exemption."
                        )
                    )
                }
            }
            #expect(
                found,
                Comment(
                    rawValue: "\(name) is exempt but not found"
                )
            )
        }
    }

    @Test("Tests reach the bridge only through the resolver seam")
    func testsReachTheBridgeThroughTheSeam() throws {
        let needle = "WMBridge."
        let seam = "classResolverOverride"
        var reached: [String] = []
        var strays: [String] = []
        for tree in Self.testTrees {
            for file in try SourceScan.swiftSources(under: tree)
            where !Self.scanExempt.contains(file.lastPathComponent) {
                let source = SourceScan.stripComments(
                    try String(contentsOf: file, encoding: .utf8)
                )
                guard source.contains(needle) else { continue }
                reached.append(file.lastPathComponent)
                if !source.contains(seam) {
                    strays.append(file.lastPathComponent)
                }
            }
        }
        // Non-vacuous: the plumbing suite itself must be seen.
        // The exemption's own liveness is
        // `scanExemptEntriesAreLive` — an exclusion keyed on the
        // same name it would assert about cannot check itself.
        #expect(reached.contains("WMBridgeTests.swift"))
        #expect(
            strays.isEmpty,
            """
            \(strays.joined(separator: ", ")) reaches WMBridge \
            without setting classResolverOverride — the default \
            path is a live WindowServer read, cached for the \
            whole process.
            """
        )
    }
}
