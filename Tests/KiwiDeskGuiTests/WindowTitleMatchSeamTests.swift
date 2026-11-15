import Foundation
import Testing

/// A window title is matched against a rule's fragment by ONE
/// predicate, `WindowTitleMatch` (#2103 ruling 43): App Rules'
/// Float rows, its titled Space rows (#3341) and a KiwiVision lens
/// member all read a title rule, and a second spelling of the match
/// beside any would let one pattern pick different windows.
///
/// Reads comment-stripped Core source; no main actor.
@Suite("Window title match seam (#2103)")
struct WindowTitleMatchSeamTests {
    /// Core's files, comments stripped, by path under Core, so two
    /// files sharing a name never shadow each other.
    private func coreSources() throws -> [String: String] {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        var sources: [String: String] = [:]
        for url in try SourceScan.swiftSources(under: root) {
            let path = String(url.path.dropFirst(root.path.count + 1))
            sources[path] = try SourceScan.strippedSource(at: url)
        }
        #expect(sources.count > 100, "Core read empty")
        return sources
    }

    /// The Float rules, the titled Space rules and the lens resolver
    /// each ask the predicate, once, and nothing else in Core does.
    @Test("every title rule asks the one predicate")
    func everyRuleAsksThePredicate() throws {
        let callers = try coreSources()
            .mapValues { $0.occurrences(of: "WindowTitleMatch.matches(") }
            .filter { $0.value > 0 }
        #expect(
            callers == [
                "AX/WindowRules.swift": 1,
                "Models/TitledSpaceRules.swift": 1,
                "App/KiwiCore+VisionLens.swift": 1,
            ]
        )
    }

    /// The substring match lives in the predicate's body alone. The
    /// needle is the shape a title rule takes today; a match spelled
    /// otherwise (`range(of:`, an optional chain) is review's.
    @Test("the match is spelled in one place")
    func matchHasOneHome() throws {
        let homes = try coreSources()
            .filter { $0.value.contains("title.contains(") }
            .keys
        #expect(Set(homes) == ["Models/AppTitleRule.swift"])
        let rules = try #require(
            try coreSources()["Models/AppTitleRule.swift"]
        )
        #expect(rules.occurrences(of: "title.contains(") == 1)
    }
}
