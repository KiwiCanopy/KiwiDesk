import Foundation
import Testing

@testable import KiwiDeskCore

/// Every private path the source resolves is one `self_test`
/// probes, and every probe names a path the source resolves
/// (#1889). The resolvers are reached by string, so nothing in
/// the compiler ties a new `dlsym` symbol to the self-test: this
/// scan does, by reading each literal handed to a resolver.
///
/// A probe row takes its name from the home's `PrivateSymbol`, so
/// a name is spelled once — `nameIsSpelledOnce` holds that, and
/// that no self-test file resolves anything itself.
///
/// The hand-mirrored pair that survives is deliberate: the C read
/// roster below (and the bridge's in `PrivatePathSelfTestTests`)
/// restates which paths the run CALLS, apart from the code that
/// decides it, so a write reclassified as a read is a red here
/// rather than a call on the desk.
@Suite("Every private path is self-tested (#1889)")
@MainActor
struct PrivatePathCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// Resolver literals that are not private fast paths, each
    /// with why.
    private static let exempt: [String: String] = [
        "objc_msgSend":
            "the ObjC runtime's dispatch, public; the bridge's "
            + "operations it sends are probed by class"
    ]

    /// The C symbols the read-only run calls (or reads a past
    /// call of). Everything else resolved by `dlsym` is looked up
    /// only; a name moving onto this list is a reviewed decision.
    private static let cReads: Set<String> = [
        "SLSMainConnectionID", "SLSGetActiveSpace",
        "SLSCopyManagedDisplaySpaces",
        "SLSManagedDisplayGetCurrentSpace", "SLSGetWindowBounds",
        "SLSCopyWindowsWithOptionsAndTags", "SLSCopySpacesForWindows",
        "SLSWindowQueryWindows", "SLSWindowQueryResultCopyWindows",
        "SLSWindowIteratorGetCount", "SLSWindowIteratorAdvance",
        "SLSWindowIteratorGetCornerRadii", "SLSGetEventPort",
        "_CFMachPortSetOptions", "SLSRegisterNotifyProc",
        "CGDisplayCreateUUIDFromDisplayID",
    ]

    /// The resolver spellings: the three named resolvers, a bare
    /// `dlsym(<handle>, "X")`, and the bridge roster's raw values.
    private static let resolverPatterns = [
        #"\b(?:symbol|coreFoundationSymbol|globalSymbol)"#
            + #"\(\s*"([^"]+)"\s*,\s*as:"#,
        #"\bdlsym\(\s*[^"()]*(?:\([^()]*\))?\s*,\s*"([^"]+)"\s*\)"#,
    ]
    private static let operationPattern = #"=\s*"([A-Za-z]+Operation)""#

    private func sources() throws -> [(URL, String)] {
        let tree = Self.root.appendingPathComponent("Sources")
        var out: [(URL, String)] = []
        for root in SourceScan.targetTrees(under: tree) {
            for file in try SourceScan.swiftSources(under: root) {
                out.append(
                    (
                        file,
                        SourceScan.stripComments(
                            try String(contentsOf: file, encoding: .utf8)
                        )
                    )
                )
            }
        }
        return out
    }

    private func matches(
        _ pattern: String,
        in source: String
    ) throws -> [String] {
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(source.startIndex..., in: source)
        return regex.matches(in: source, range: range).compactMap {
            Range($0.range(at: 1), in: source).map { String(source[$0]) }
        }
    }

    /// Name → file, for every literal a resolver is handed.
    private func resolvedLiterals() throws -> [String: String] {
        var found: [String: String] = [:]
        for (file, source) in try sources() {
            let patterns = Self.resolverPatterns + [Self.operationPattern]
            for pattern in patterns {
                for name in try matches(pattern, in: source) {
                    found[name] = file.lastPathComponent
                }
            }
        }
        return found
    }

    @Test("every resolver literal has a probe, and every probe a literal")
    func catalogMatchesTheSource() throws {
        let literals = try resolvedLiterals()
        let probed = PrivatePathSelfTest.catalog(.empty).map(\.name)
        #expect(Set(probed).count == probed.count, "a probe repeats")
        // Non-vacuous: the scan must see SkyLight, the event port
        // and the bridge roster at least.
        #expect(literals["SLSGetActiveSpace"] == "SkyLight.swift")
        #expect(literals["_CFMachPortSetOptions"] != nil)
        #expect(
            literals["CGDisplayCreateUUIDFromDisplayID"]
                == "NativeSpaces.swift"
        )
        #expect(
            literals["HideSpacesOperation"] == "WMBridge+Operation.swift"
        )
        let resolved = Set(literals.keys)
            .subtracting(Self.exempt.keys)
        let unprobed = resolved.subtracting(probed).sorted()
        #expect(
            unprobed.isEmpty,
            """
            resolved but never self-tested: \
            \(unprobed.map { "\($0) (\(literals[$0] ?? ""))" }) — \
            add a probe in the home that resolves it
            """
        )
        let stale = Set(probed).subtracting(resolved).sorted()
        #expect(stale.isEmpty, "probes naming no resolver: \(stale)")
        for name in Self.exempt.keys {
            #expect(literals[name] != nil, "\(name) is exempt but gone")
        }
    }

    /// A name is spelled once, at its lookup — a second spelling
    /// is a second resolution or a row naming it by hand — and no
    /// self-test file resolves anything.
    @Test("a resolved name is spelled once, never in a self-test file")
    func nameIsSpelledOnce() throws {
        let literals = try resolvedLiterals()
            .filter { Self.exempt[$0.key] == nil }
        #expect(literals.count > 20)
        let files = try sources()
        for name in literals.keys.sorted() {
            let spellings = files.filter {
                $0.1.contains("\"\(name)\"")
            }
            #expect(
                spellings.count == 1,
                """
                \(name) is spelled in \
                \(spellings.map(\.0.lastPathComponent)) — take the \
                name from its PrivateSymbol
                """
            )
        }
        for (file, source) in files {
            let name = file.lastPathComponent
            guard
                name.hasSuffix("+SelfTest.swift")
                    || name == "PrivatePathSelfTest.swift"
            else { continue }
            for pattern in Self.resolverPatterns {
                #expect(
                    try matches(pattern, in: source).isEmpty,
                    "\(name) resolves a symbol itself"
                )
            }
        }
    }

    @Test("only the listed C symbols are called by the run")
    func cReadRosterIsPinned() {
        let reads = PrivatePathSelfTest.catalog(.empty)
            .filter { $0.kind == .symbol && $0.access == .read }
            .map(\.name)
        #expect(Set(reads) == Self.cReads)
    }
}
