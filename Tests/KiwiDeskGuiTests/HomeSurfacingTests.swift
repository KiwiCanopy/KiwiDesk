import Foundation
import Testing

@testable import KiwiDesk

/// The Home shell's surfacing branches and one-line wiring
/// decisions (#678 turn 9), pinned by needles on the USE sites
/// — the Monitors lesson, three times paid for: a surfacing
/// gate ends in an `if` inside a `body`, and every other guard
/// passes whether or not that `if` was ever written. Comments
/// are stripped (a comment quoting a key must not stand in for
/// a call site) and whitespace squashed, and each needle names
/// the branch TOGETHER with what it draws or decides.
///
/// Stated limit: these are existence pins, not behavior — the
/// behavior halves live in `HomeCardOrderTests`,
/// `HomeCardContentTests` and `SettingsModeNavigationTests`.
/// What only these can see is a branch or a wiring line being
/// deleted whole with the suite green
/// (`ZOrderSequenceWiringTests` is the precedent).
@Suite("Home surfacing branches")
struct HomeSurfacingTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )

    // The needle map lives in `HomeSurfacingTests+Needles.swift`.
    @Test("every surfacing branch is drawn where it decides")
    func branchesAreDrawn() throws {
        for (path, wanted) in Self.needles {
            let url = Self.root
                .appendingPathComponent("Sources/KiwiDesk")
                .appendingPathComponent(path)
            let raw = try String(
                contentsOf: url,
                encoding: .utf8
            )
            #expect(!raw.isEmpty)
            let squashed = SourceScan.stripComments(raw)
                .split(whereSeparator: \.isWhitespace)
                .joined()
            for needle in wanted {
                #expect(
                    squashed.contains(needle),
                    Comment(
                        rawValue:
                            "\(path) lost its branch or wiring: "
                            + needle
                    )
                )
            }
        }
    }
}
