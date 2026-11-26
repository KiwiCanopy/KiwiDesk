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

    /// A measured strip, the key its chips carry, the item it
    /// follows when no chip is focused, and its chip builder call.
    private static let strips = [
        (
            path: "Sections/LayerStripEditor.swift",
            key: "name", fallback: "selected",
            chip: "layerChip(name)"
        ),
        (
            path: "Components/SpaceOverrides/SpacePreviewChipRow.swift",
            key: "candidate.raw", fallback: "shown?.raw",
            chip: "chip(candidate)"
        ),
    ]

    /// Each measured strip writes each chip's size under its key,
    /// reads its run through `measured`, and follows by name through
    /// `StripFollow.named`, its chips scroll-addressable and
    /// focusable by that key. A strip spelling any of it another way
    /// reds here.
    @Test("each measured strip measures, runs and follows")
    func measuredWiring() throws {
        for strip in Self.strips {
            let source = try Self.squashed(strip.path)
            let key = strip.key
            let note = Comment(rawValue: strip.path)
            #expect(!source.isEmpty, note)
            #expect(
                source.contains("run:.measured(names,sizes:chipSizes,"),
                note
            )
            #expect(
                source.contains(
                    ".onGeometryChange(for:CGSize.self){$0.size}"
                        + "action:{chipSizes[\(key)]=$0}"
                ),
                note
            )
            #expect(source.contains("followed:followed(in:names)"), note)
            #expect(
                source.contains(
                    ".named(focused:focusedChip,else:"
                        + "\(strip.fallback),in:names)"
                ),
                note
            )
            #expect(source.contains("\(strip.chip).id(\(key))"), note)
            #expect(
                source.contains(".focused($focusedChip,equals:\(key))"),
                note
            )
            #expect(!source.contains("StripRun(lengths:"), note)
        }
    }

    @Test("a named follow takes the listed focus, else the fallback")
    func namedFollow() {
        let names = ["1", "2", "web"]
        let follow = StripFollow<String>.named
        #expect(
            follow("web", "1", names) == StripFollow(id: "web", index: 2)
        )
        #expect(follow(nil, "2", names) == StripFollow(id: "2", index: 1))
        #expect(
            follow("gone", "2", names) == StripFollow(id: "2", index: 1)
        )
        #expect(follow(nil, "gone", names) == nil)
        #expect(follow(nil, nil, names) == nil)
    }
}
