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
                .appendingPathComponent("Sources/KiwiDeskCore/App")
                .appendingPathComponent("KiwiCore+ShelfRevealCommand.swift")
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
        // The empty pill is `emptyRefusal`'s verdict (its behaviour is
        // `ShelfRefusalPlaceTests` ▸ `emptyRefusalAsksTheContent`).
        #expect(body.contains("emptyRefusal(bar, on: display)"))
        #expect(body.contains("has nothing to show here"))
        // A stood-down shelf is asked first, so its missing target
        // never reads as an empty bar.
        let standDown = try #require(
            body.range(of: "shelfStandsDown(on: display)")
        )
        let empty = try #require(
            body.range(of: "emptyRefusal(bar, on: display)")
        )
        #expect(standDown.lowerBound < empty.lowerBound)
    }

    @Test("A stood-down shelf refuses with its pill, before the rest")
    func standDownIsCuedFirst() throws {
        let body = try Self.body
        // The command's behaviour is `ShelfRefusalPlaceTests` ▸
        // `standDownRefusesFirst`; the layout check has no fixture.
        let cue = try #require(
            body.range(of: "cueRevealRefusal(.standsDown(bar)")
        )
        for later in [".noAppBarHere", ".alwaysShown(bar)"] {
            let range = try #require(body.range(of: later))
            #expect(cue.lowerBound < range.lowerBound, "\(later)")
        }
    }

    @Test("Each refusal reads its own sentence")
    func sentencesAreDistinct() {
        LocalizationManager.shared.select("en")
        let refusals: [KiwiCore.RevealRefusal] = [
            .alwaysShown(.space), .alwaysShown(.app),
            .shownBesideAlways(.space), .shownBesideAlways(.app),
            .noAppBarHere,
            .nothingToShow(.space), .nothingToShow(.app),
            .standsDown(.space),
        ]
        let texts = refusals.map(KiwiCore.revealRefusalText)
        #expect(texts.allSatisfy { !$0.isEmpty })
        #expect(Set(texts).count == refusals.count)
        #expect(
            KiwiCore.revealRefusalText(.nothingToShow(.app))
                == "No windows for the App Bar here"
        )
        // One sentence for both bars: the stand-down hides both.
        #expect(
            KiwiCore.revealRefusalText(.standsDown(.app))
                == KiwiCore.revealRefusalText(.standsDown(.space))
        )
    }
}
