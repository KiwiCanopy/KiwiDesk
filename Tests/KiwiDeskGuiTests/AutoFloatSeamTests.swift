import Foundation
import Testing

/// The escape's two doors (#2173): one writer of the live float
/// rules, so a changed guess is always judged, and one derivation
/// of the overlay flag, which track and every recheck take.
@Suite("Automatic float seams (#2173)")
struct AutoFloatSeamTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    @Test("installFloatRules is the one writer of the live float rules")
    func oneWriter() throws {
        var found: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: Self.core) {
            let hits = try SourceScan.strippedSource(at: file)
                .occurrences(of: "eventLoop.floatRules =")
            if hits > 0 { found[file.lastPathComponent] = hits }
        }
        #expect(found == ["KiwiCore+AutoFloat.swift": 1])
    }

    @Test("track and the recheck take the one overlay derivation")
    func oneOverlayDerivation() throws {
        let tracking = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "Events/EventLoop+Tracking.swift"
            )
        )
        #expect(
            tracking.contains("window.isTransientOverlay = Self.isOverlay(")
        )
        #expect(tracking.occurrences(of: "Self.isOverlay(") >= 3)
        #expect(tracking.contains(".windowOverlayChanged(id, isOverlay:"))
    }
}

/// The card's grey-don't-hide branches (#2173): each is an `if` or
/// a modifier no other guard sees, so each is needled at its site.
@Suite("Automatic floating card branches (#2173)")
struct AutoFloatCardBranchTests {
    @Test("the card draws its greys, its notes and its live controls")
    func branchesAreDrawn() throws {
        let card = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Sections/"
                        + "AppRulesSection+Automatic.swift"
                )
        )
        for needle in [
            "if !automaticOn, !tileApps.isEmpty {",
            "Text(AutoFloatWords.offNote)",
            "GreyOut(active: !automaticOn, help: AutoFloatWords.offNote)",
            "GreyOut(active: dimmed, help: AutoFloatWords.offNote)",
            "dimmed: !automaticOn,",
            "if Self.floatsEveryWindow(app: app, config: model.config) {",
            "Text(AutoFloatWords.inert)",
        ] {
            #expect(card.contains(needle), "\(needle)")
        }
        // The trash and the reach stay outside the dim.
        let row = try #require(card.range(of: "struct AppRuleTileRow"))
        let rowBody = String(card[row.lowerBound...])
        #expect(rowBody.occurrences(of: "GreyOut(") == 1)
        let identity = try Self.statement(
            in: rowBody,
            from: "AppRuleIdentity(app: app)",
            to: "if showsReach"
        )
        #expect(identity.contains("GreyOut(active: dimmed"))
        let trash = try Self.statement(
            in: rowBody,
            from: "AppRuleDeleteButton(",
            to: "floatsEveryWindow(app:"
        )
        #expect(!trash.contains("GreyOut("))
    }

    /// The text from `start` up to the next `end` after it.
    private static func statement(
        in source: String,
        from start: String,
        to end: String
    ) throws -> Substring {
        let open = try #require(source.range(of: start))
        let close = try #require(
            source.range(of: end, range: open.upperBound..<source.endIndex)
        )
        return source[open.lowerBound..<close.lowerBound]
    }
}
