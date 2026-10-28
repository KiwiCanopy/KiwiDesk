import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Pocket's position slider names where it runs (owner,
/// 2026-10-28): arrows at its ends follow the edge, and VoiceOver
/// hears which end the percentage counts from.
@Suite("Pocket position names its ends")
@MainActor
struct PocketPositionEndsTests {
    @Test("the ends follow the edge's orientation")
    func endsFollowTheEdge() {
        for edge in AppBarEdge.allCases {
            let ends = PocketGroup.ends(edge)
            #expect(
                edge.isHorizontal
                    ? ends == ("arrow.left.to.line", "arrow.right.to.line")
                    : ends == ("arrow.up.to.line", "arrow.down.to.line"),
                "\(edge)"
            )
        }
    }

    @Test("the spoken value names the end it counts from")
    func spokenNamesTheEnd() {
        LocalizationManager.shared.select("en")
        #expect(
            PocketGroup.spokenPosition("82%", edge: .bottom)
                == "82% from the left"
        )
        #expect(
            PocketGroup.spokenPosition("82%", edge: .right)
                == "82% from the top"
        )
    }

    @Test("the row hands the slider both")
    func rowWiresBoth() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Keybindings/"
                    + "PocketGroup.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        #expect(source.contains("spokenValue:Self.spokenPosition("))
        #expect(source.contains("ends:Self.ends(pocket.wrappedValue.edge)"))
    }
}
