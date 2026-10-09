import Foundation
import Testing

@testable import KiwiDeskCore

/// Every private path the source resolves is one `self_test`
/// probes, and every probe names a path the source resolves
/// (#1889). The resolvers are reached by string, so nothing in
/// the compiler ties a new `dlsym` symbol to the self-test: this
/// scan does, by reading each literal handed to a resolver.
/// Bridge classes need no scan beyond the roster file — the probes
/// are `WMBridge.Operation`'s cases, which `make` takes.
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

    /// `symbol("X", as:` / `coreFoundationSymbol("X", as:` and
    /// `dlsym(<handle>, "X")`, the three resolver spellings.
    private static let patterns = [
        #"\b(?:symbol|coreFoundationSymbol)\(\s*"([^"]+)"\s*,\s*as:"#,
        #"\bdlsym\(\s*[^"()]*(?:\([^()]*\))?\s*,\s*"([^"]+)"\s*\)"#,
        // The bridge roster: every operation's short name.
        #"=\s*"([A-Za-z]+Operation)""#,
    ]

    private func resolvedLiterals() throws -> [String: String] {
        var found: [String: String] = [:]
        let sources = Self.root.appendingPathComponent("Sources")
        for tree in SourceScan.targetTrees(under: sources) {
            for file in try SourceScan.swiftSources(under: tree) {
                let source = SourceScan.stripComments(
                    try String(contentsOf: file, encoding: .utf8)
                )
                for pattern in Self.patterns {
                    let regex = try NSRegularExpression(pattern: pattern)
                    let range = NSRange(source.startIndex..., in: source)
                    for match in regex.matches(in: source, range: range) {
                        guard
                            let span = Range(match.range(at: 1), in: source)
                        else { continue }
                        found[String(source[span])] =
                            file.lastPathComponent
                    }
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
}
