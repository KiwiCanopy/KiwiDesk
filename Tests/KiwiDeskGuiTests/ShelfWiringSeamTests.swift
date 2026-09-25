import Foundation
import Testing

/// Wiring the shelf's behavioural suites cannot see, because each
/// drives a primitive rather than the call site that composes it
/// (#1517, guard-prover): `updateBars` holds relayout around BOTH
/// bar syncs, and the divider's report reaches `execute` only on a
/// release, from the one Bootstrap wiring that passes `committed`
/// through.
@Suite("Shelf wiring seams")
struct ShelfWiringSeamTests {
    private static var core: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    private static func body(
        of declaration: String,
        in file: String
    ) throws -> String {
        let source = try SourceScan.strippedSource(
            at: core.appendingPathComponent(file)
        )
        let body = try #require(
            SourceScan.declarationBody(after: declaration, in: source)
        )
        return String(body)
    }

    private static func squash(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined()
    }

    /// Every bar sync in `updateBars` sits inside a
    /// `holdingRelayout` scope: a sync outside it re-lays the
    /// shelf against the previous plan mid-refresh.
    @Test("updateBars syncs both bars inside the relayout hold")
    func updateBarsHoldsRelayout() throws {
        let body = Self.squash(
            try Self.body(
                of: "func updateBars(",
                in: "App/KiwiCore+Shelf.swift"
            )
        )
        #expect(!body.isEmpty)
        let scopes = body.components(separatedBy: "shelves.holdingRelayout{")
            .dropFirst()
        #expect(scopes.count == 2, "the fallback and the per-display arm")
        for scope in scopes {
            let inner = String(scope.prefix(while: { $0 != "}" }))
            #expect(inner.contains("appBars.sync("))
            #expect(inner.contains("spaceBars.sync("))
        }
        let syncs = body.components(separatedBy: "Bars.sync(").count - 1
        #expect(syncs == 4, "a bar sync outside the two scopes")
    }

    /// A step re-lays the bars; the release — and only it — takes
    /// `execute`, the settings-apply door.
    @Test("The drag's release takes execute, a step does not")
    func dragRoutesTheRelease() throws {
        let body = Self.squash(
            try Self.body(
                of: "func dragShelfMinimum(",
                in: "App/KiwiCore+ShelfDivider.swift"
            )
        )
        let step = try #require(
            body.range(of: "guardcommittedelse{").map {
                String(body[$0.upperBound...].prefix(while: { $0 != "}" }))
            }
        )
        #expect(step.contains("updateBars()"))
        #expect(!step.contains("execute("))
        #expect(
            body.components(separatedBy: "execute(\"kiwishelf.set_minimum\"")
                .count - 1 == 1
        )
        let boot = Self.squash(
            try Self.body(
                of: "func bootstrapCoreServices(",
                in: "App/KiwiCore+Bootstrap.swift"
            )
        )
        #expect(boot.contains("dragShelfMinimum(percent,committed:committed)"))
    }

    /// Both item views take hover only where they own the pointer,
    /// so the overflow count drawn over an item takes it there.
    @Test("Bar items gate hover on owning the pointer")
    func itemsGateHover() throws {
        for file in [
            "Bar/SpaceBarItemView.swift", "Bar/AppBarItemView.swift",
        ] {
            let body = Self.squash(
                try Self.body(of: "func refreshHover(", in: file)
            )
            #expect(
                body.contains("BarHoverHit.owns(self,event)"),
                Comment(rawValue: file)
            )
            let source = Self.squash(
                try SourceScan.strippedSource(
                    at: Self.core.appendingPathComponent(file)
                )
            )
            // Every hover-on path runs through the one refresh.
            #expect(
                source.components(separatedBy: "isHovered=true").count == 1,
                Comment(rawValue: file)
            )
        }
    }
}
