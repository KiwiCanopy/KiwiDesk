import Foundation
import Testing

/// Detection's float verdict has one reader per purpose (#1810,
/// #2975):
/// the float verbs and the bar menu's Float/Tile row read it
/// through `KiwiCore.tileRefusal(of:)`, never beside it, and the
/// verdict is composed in `EventLoop.autoFloatVerdict` alone. A
/// second reader is where the row and the pill would come apart,
/// and every behaviour suite hands the verdict in, so none sees a
/// reader going round the door. Scanned here because `SourceScan`
/// lives in the GUI test target (AGENTS.md §1).
@Suite("Tile refusal seam (#1810)")
struct TileRefusalSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// Stripped Core source per file path under `KiwiDeskCore/`.
    private static func coreSources() throws -> [String: String] {
        let base = root.appendingPathComponent("Sources/KiwiDeskCore")
        var found: [String: String] = [:]
        for file in try SourceScan.swiftSources(under: base) {
            let key = String(
                file.path.dropFirst(base.path.count + 1)
            )
            found[key] = try SourceScan.strippedSource(at: file)
        }
        return found
    }

    /// Per file, how often `needle` appears, zero-count files left
    /// out.
    private static func census(
        _ needle: String,
        in sources: [String: String]
    ) -> [String: Int] {
        sources.compactMapValues {
            let count = $0.occurrences(of: needle)
            return count > 0 ? count : nil
        }
    }

    @Test("the verdict is read only by tileRefusal")
    func verdictHasOneReader() throws {
        let sources = try Self.coreSources()
        #expect(sources.count > 100, "the scan read too little")
        #expect(
            // Call-shaped: the declaration spells `(for id:`.
            Self.census("detectionVerdict(for:", in: sources) == [
                "Commands/KiwiCore+FloatCommands.swift": 1
            ]
        )
        let door = try SourceScan.functionBody(
            of: "tileRefusal",
            in: "KiwiCore+FloatCommands.swift",
            under: "Commands"
        )
        #expect(door.contains("detectionVerdict(for:"))
    }

    /// The raw store is internal, so the door is only a door if
    /// no file beyond the event loop's own spells it: its
    /// declaration, reset, writers, re-key and the query.
    @Test("the verdict store stays inside the event loop")
    func storeStaysInTheEventLoop() throws {
        let sources = try Self.coreSources()
        #expect(
            Set(Self.census("detectedFloating", in: sources).keys) == [
                "Events/EventLoop.swift",
                "Events/EventLoop+Lifecycle.swift",
                "Events/EventLoop+Tracking.swift",
                "Events/EventLoop+Notifications.swift",
                "Events/EventLoop+Tabs.swift",
                "Events/EventLoop+Queries.swift",
                // A changed guess forgets verdicts (#2173).
                "Events/EventLoop+FloatVerdict.swift",
            ]
        )
    }

    /// The verbs and the row, and nobody else: a new reader
    /// states itself here.
    @Test("tileRefusal's callers are the verbs and the menu row")
    func doorCallers() throws {
        let sources = try Self.coreSources()
        let calls = Self.census("tileRefusal(of:", in: sources)
        #expect(
            calls == [
                // The verb's refusal and the menu row's
                // `tileRefused` (the declaration spells `(of id:`).
                "Commands/KiwiCore+FloatCommands.swift": 2,
                // The Tile picker's open guesses, which App
                // Rules… lands on too (#2173, #2071).
                "App/KiwiCore+AutoFloat.swift": 1,
                // `explain_window`'s cause (#1685).
                "Commands/KiwiCore+Explain.swift": 1,
                // Unmarking tiles as a Tile does (#2680).
                "Commands/KiwiCore+PocketWindow.swift": 1,
                // The Tile over a rule's reader and its carried
                // restore (#2975).
                "App/KiwiCore+TileOverRule.swift": 2,
            ]
        )
    }

    /// A Tile refuses by one predicate on the reason (#2975), which
    /// the verb, the menu row, `explain_window` and the pocket's
    /// unmark all ask: a reader comparing the reason beside it is
    /// where the row and the verb would come apart again.
    @Test("a Tile refuses through refusesTile alone")
    func refusalHasOnePredicate() throws {
        let sources = try Self.coreSources()
        #expect(
            Self.census(".refusesTile", in: sources) == [
                "Commands/KiwiCore+FloatCommands.swift": 2,
                "Commands/KiwiCore+Explain.swift": 1,
                "Commands/KiwiCore+PocketWindow.swift": 1,
                // The reason change that ends a Tile over a rule.
                "Events/EventLoop+Tracking.swift": 1,
            ]
        )
        let row = try SourceScan.functionBody(
            of: "floatRow",
            in: "KiwiCore+BarWindowMenus.swift",
            under: "App"
        )
        #expect(row.occurrences(of: "tileRefused(id)") == 2)
        let door = try SourceScan.functionBody(
            of: "tileRefused",
            in: "KiwiCore+FloatCommands.swift",
            under: "Commands"
        )
        #expect(door.contains("$0.refusesTile"))
        // A comparison with the rule beside the predicate decides
        // whether the record applies, never a refusal; a new one
        // states itself here.
        var ruleReads: [String: Int] = [:]
        for needle in ["== .rule", "!= .rule", ".floats(.rule)"] {
            ruleReads.merge(
                Self.census(needle, in: sources),
                uniquingKeysWith: +
            )
        }
        #expect(
            ruleReads == [
                // The reader's and the restore's verdict.
                "App/KiwiCore+TileOverRule.swift": 2,
                // The verb's record branch and its no-op Float.
                "Commands/KiwiCore+FloatCommands.swift": 2,
                // The latch's kept verdict and the reason change.
                "Events/EventLoop+Tracking.swift": 3,
            ]
        )
    }

    /// The record is applied by one Core reader, ahead of the fold,
    /// and every event reaches it (#2975): a second reader beside
    /// it is a second composition of the verdict.
    @Test("a Tile over a rule has one reader, ahead of the fold")
    func tileOverRuleHasOneReader() throws {
        let sources = try Self.coreSources()
        #expect(
            Self.census("applyingTileOverRule(", in: sources) == [
                "App/KiwiCore+TileOverRule.swift": 1,
                "App/KiwiCore+Events.swift": 1,
            ]
        )
        let handle = try SourceScan.functionBody(
            of: "handle",
            in: "KiwiCore+Events.swift",
            under: "App"
        )
        let reader = try #require(
            handle.range(of: "applyingTileOverRule(event)")
        )
        let fold = try #require(handle.range(of: "state.apply(event)"))
        #expect(reader.lowerBound < fold.lowerBound)
    }

    @Test("the verdict is composed in autoFloatVerdict alone")
    func oneComposition() throws {
        let sources = try Self.coreSources()
        #expect(
            Self.census("FloatDetection.autoFloatReason(", in: sources)
                == [
                    "Events/EventLoop+FloatVerdict.swift": 1,
                    // Detection's one body over the facts the
                    // off-main list read found (#1933); the verdict
                    // is composed in `autoFloatVerdict` as `.read`.
                    "Events/EventLoop+ListedWindows.swift": 1,
                ]
        )
        // The pure composition derives the force-float reason
        // and asks detection (`WindowFactsSeamTests` holds the
        // live delegation).
        let composition = try SourceScan.functionBody(
            of: "composeVerdict",
            in: "EventLoop+FloatVerdict.swift",
            under: "Events"
        )
        #expect(composition.contains("FloatDetection.autoFloatReason("))
        // Bound and used: a discarded reason forces nothing.
        #expect(composition.contains("if let forced = forceFloatReason("))
        #expect(composition.contains("return .floats(forced)"))
        // Both producers take the one composition.
        let tracking = sources["Events/EventLoop+Tracking.swift"] ?? ""
        // `track`, `recheckFloat` and its off-main twin (#1933).
        #expect(tracking.occurrences(of: "autoFloatVerdict(") == 3)
    }
}
