import Foundation
import Testing

/// The Desktop switch batch's wirings no unit test reaches
/// (#2347): the settle's deferred task parks behind the batch, and
/// bootstrap pays the held bars from the batch's fold. Both seams
/// default inert — the settle would run unparked and the bars stay
/// owed with every behaviour suite green — so each is pinned by
/// exact count to its file.
@Suite("Switch reconcile wirings (#2347)")
struct SwitchReconcileSeamTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    /// needle → (the file that carries it, how often).
    private static let wirings: [(String, String, Int)] = [
        (
            "self?.eventLoop.settleAfterSwitchReads {",
            "KiwiCore+DesktopSettle.swift", 1
        ),
        (
            "eventLoop.switchReads.onApplied = {",
            "KiwiCore+Bootstrap.swift", 1
        ),
        // The one door that holds a refresh.
        (
            "guard !eventLoop.switchReads.isPending else {",
            "KiwiCore+Shelf.swift", 1
        ),
    ]

    @Test("each wiring exists exactly once, in its own file")
    func wiringsAreSingular() throws {
        for (needle, file, count) in Self.wirings {
            let sites = try SourceScan.identifierSites(
                of: needle,
                under: Self.core
            )
            #expect(
                sites.count == count
                    && sites.allSatisfy {
                        $0.file.lastPathComponent == file
                    },
                """
                expected \(count) `\(needle)` in \(file), found: \
                \(sites.map(\.site).joined(separator: ", "))
                """
            )
        }
    }

    @Test("the settle body runs inside the parked closure")
    func settleBodyIsParked() throws {
        let source = try SourceScan.strippedSource(
            at: Self.core.appendingPathComponent(
                "Profiles/KiwiCore+DesktopSettle.swift"
            )
        )
        let body = try #require(
            SourceScan.declarationBody(
                after: "func settleAfterDesktopSwitch(",
                in: source
            )
        )
        let park = try #require(
            body.range(of: "settleAfterSwitchReads {")
        )
        let settle = try #require(body.range(of: "desktopSettle(ifStill:"))
        #expect(park.upperBound < settle.lowerBound)
        #expect(
            body.components(separatedBy: "desktopSettle(ifStill:").count
                == 2,
            "a second, unparked settle call"
        )
    }
}
