import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk

/// A strip whose items vary in width builds its run from what they
/// drew (#2990, #3263): the one `StripRun.measured`, fed by each
/// item's `onGeometryChange`, its items scroll-addressable by name.
@Suite("Sideways strip measured runs")
struct SidewaysStripMeasuredTests {
    private static func squashed(_ path: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings/" + path)
        return try SourceScan.strippedSource(at: url)
            .split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("a measured run takes bare widths and the shown depth")
    func measuredRun() {
        let run = StripRun.measured(
            ["a", "b", "c"],
            sizes: [
                "a": CGSize(width: 40, height: 20),
                "c": CGSize(width: 60, height: 22),
                "gone": CGSize(width: 10, height: 90),
            ],
            gap: 6,
            endRoom: 4
        )
        #expect(run.lengths == [40, 0, 60])
        #expect(run.depth == 22)
        #expect(run.gap == 6 && run.endRoom == 4)
    }

    /// Each measured strip writes its sizes from the item, reads its
    /// run through `measured` and follows by name. A strip spelling
    /// the run another way reds here.
    @Test("each measured strip measures, runs and follows")
    func measuredWiring() throws {
        for path in [
            "Sections/LayerStripEditor.swift",
            "Components/SpaceOverrides/SpacePreviewChipRow.swift",
        ] {
            let source = try Self.squashed(path)
            let note = Comment(rawValue: path)
            #expect(!source.isEmpty, note)
            #expect(
                source.contains("run:.measured(names,sizes:chipSizes,"),
                note
            )
            #expect(
                source.contains(
                    ".onGeometryChange(for:CGSize.self){$0.size}"
                        + "action:{chipSizes["
                ),
                note
            )
            #expect(source.contains("followed:followed(in:names)"), note)
            #expect(!source.contains("StripRun(lengths:"), note)
        }
    }

    @Test("the Spaces chips follow the focused chip, else the shown")
    func spacesFollow() {
        let names = ["1", "2", "web"]
        let follow = SpacePreviewChipRow.followed
        #expect(
            follow("web", "1", names) == StripFollow(id: "web", index: 2)
        )
        #expect(follow(nil, "2", names) == StripFollow(id: "2", index: 1))
        #expect(
            follow("gone", "2", names) == StripFollow(id: "2", index: 1)
        )
        #expect(follow(nil, nil, names) == nil)
    }

    @Test("the Spaces chips take focus and are named by their Space")
    func spacesWiring() throws {
        let source = try Self.squashed(
            "Components/SpaceOverrides/SpacePreviewChipRow.swift"
        )
        #expect(source.contains("chip(candidate).id(candidate.raw)"))
        #expect(
            source.contains(".focused($focusedChip,equals:candidate.raw)")
        )
        #expect(
            source.contains(
                "Self.followed(focused:focusedChip,"
                    + "shown:shown?.raw,in:names)"
            )
        )
    }
}
