import Foundation
import Testing

@testable import KiwiDesk

/// Where a layout thumbnail may play its story (#1750). Only a
/// surface that is READ rather than compared hosts one — the
/// Layouts chooser, its detail panel and the Home cards stay at
/// rest, since they restage as feedback on a changing draft and a
/// playing tile there would pull the eye to whichever one moves
/// (`docs/design-decisions.md` ▸ *A layout gets one frame*).
@Suite("Layout story wiring (#1750)")
struct LayoutStoryWiringTests {
    /// The one copy of who may host a playing thumbnail, each
    /// with its reason.
    static let hosts: [String: String] = [
        "Onboarding/OnboardingSpaceRow.swift":
            "the tour's Spaces step, read once",
        "Settings/Components/Profiles/PresetPreviewSheet.swift":
            "a read-only preset preview; nothing in it is edited",
    ]

    private func squashed(_ url: URL) throws -> String {
        SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
    }

    private func relative(_ url: URL) -> String {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk").path
        return String(url.path.dropFirst(root.count + 1))
    }

    private func callers(of needle: String) throws -> Set<String> {
        var found: Set<String> = []
        let files = try ChromeScanRoots.sources(from: #filePath)
        #expect(files.count > 50)
        for url in files where try squashed(url).contains(needle) {
            found.insert(relative(url))
        }
        return found
    }

    @Test("only a read-only surface hosts a playing thumbnail")
    func hostsAreRuled() throws {
        #expect(
            try callers(of: "LayoutStoryThumbnail(")
                == Set(Self.hosts.keys)
        )
    }

    /// A story phase reaches a schematic only through the player,
    /// so no surface can hand one a moving frame beside it.
    @Test("only the player hands a schematic a story phase")
    func motionComesFromThePlayer() throws {
        #expect(
            try callers(of: "motion:frame.motion")
                == ["Settings/Components/Layouts/LayoutStoryThumbnail.swift"]
        )
    }

    /// The tour mounts the playing row, lazily, so a row below
    /// the fold plays when it scrolls in rather than unseen.
    @Test("the tour mounts the playing rows lazily")
    func tourMountsRows() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let spaces = try squashed(
            root.appendingPathComponent(
                "Sources/KiwiDesk/Onboarding/OnboardingView+Spaces.swift"
            )
        )
        #expect(spaces.contains("LazyVStack("))
        #expect(spaces.contains("OnboardingSpaceRow("))
        #expect(!spaces.contains("LayoutSchematicView("))
    }

    /// Under Reduce Motion the player never leaves its rest
    /// frame: the guard precedes the jump to the start frame,
    /// which no animation gate can stand in for.
    @Test("Reduce Motion never leaves the rest frame")
    func reduceMotionStaysAtRest() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let player = try squashed(
            root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Layouts/"
                    + "LayoutStoryThumbnail.swift"
            )
        )
        let guardAt = try #require(
            player.range(of: "guard!reduceMotion,story.playselse")
        )
        let jump = try #require(player.range(of: "atStart=true"))
        #expect(guardAt.upperBound < jump.lowerBound)
    }
}
