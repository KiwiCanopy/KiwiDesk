import Foundation
import Testing

@testable import KiwiDeskCore

/// A bar's show/hide that cannot show its bar says why (#761,
/// #2567 ▸ Ruling): every refusal the command returns for a reason
/// the user can act on draws its pill first, the empty bar's
/// included. The test core never starts the pill's runtime, so the
/// wiring is read off the command's body.
@Suite("A bar's show/hide refusal draws its pill (#2567)")
@MainActor
struct ShelfRevealRefusalWiringTests {
    private static var body: String {
        get throws {
            let file = SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDeskCore/App/KiwiCore+ShelfReveal.swift"
                )
            let source = try SourceScan.strippedSource(at: file)
            return try #require(
                SourceScan.declarationBody(
                    after: "func shelfRevealCommand(",
                    in: source
                ).map { String($0) }
            )
        }
    }

    @Test("Nothing to show refuses with a pill, for either bar")
    func nothingToShowIsCued() throws {
        let body = try Self.body
        #expect(body.contains("cueRevealRefusal(.nothingToShow(bar)"))
        #expect(body.contains("has nothing to show here"))
        // A stood-down shelf is asked first, so its missing target
        // never reads as an empty bar.
        let standDown = try #require(
            body.range(of: "shelfStandsDown(on: display)")
        )
        let empty = try #require(
            body.range(of: "cueRevealRefusal(.nothingToShow")
        )
        #expect(standDown.lowerBound < empty.lowerBound)
    }

    @Test("Each refusal reads its own sentence")
    func sentencesAreDistinct() {
        LocalizationManager.shared.select("en")
        let refusals: [KiwiCore.RevealRefusal] = [
            .alwaysShown(.space), .alwaysShown(.app),
            .shownBesideAlways(.space), .shownBesideAlways(.app),
            .noAppBarHere,
            .nothingToShow(.space), .nothingToShow(.app),
        ]
        let texts = refusals.map(KiwiCore.revealRefusalText)
        #expect(texts.allSatisfy { !$0.isEmpty })
        #expect(Set(texts).count == refusals.count)
        #expect(
            KiwiCore.revealRefusalText(.nothingToShow(.app))
                == "No windows for the App Bar here"
        )
    }
}
