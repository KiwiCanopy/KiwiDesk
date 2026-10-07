import CoreGraphics
import Foundation
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// The jump bar's layer readout and line placement (#1520), split
/// from `ShortcutsJumpTests` at the §2.1 ceiling: it never elides
/// the sentence — a long name is cut inside it — and it takes a
/// centred line of its own under the centred chips.
/// Serialized: one clause pins the process-wide locale.
@Suite("Shortcuts jump readout", .serialized)
@MainActor
struct ShortcutsJumpReadoutTests {
    /// A long layer name is cut inside the sentence, so "Editing
    /// the … layer" always reads whole.
    @Test("a long layer name is cut, never the sentence")
    func longNameIsCut() {
        let limit = ShortcutsJumpBar.nameLimit
        let long = String(repeating: "x", count: limit + 10)
        let shown = ShortcutsJumpBar.shownName(long)
        #expect(shown.count == limit)
        #expect(shown.hasSuffix("…"))
        let short = String(repeating: "x", count: limit)
        #expect(ShortcutsJumpBar.shownName(short) == short)
    }

    private func barHeight(
        readout: String?,
        width: CGFloat
    ) throws -> CGFloat {
        let bar = ShortcutsJumpBar(
            marked: .focus,
            underlapped: false,
            readout: readout
        ) { _ in }
        .environment(\.settingsWidth, .medium)
        .frame(width: width)
        let image = try #require(ImageRenderer(content: bar).nsImage)
        return image.size.height
    }

    /// The readout always takes a line of its own under the chips
    /// (#1520 amendment 5), even where it would fit beside them.
    /// Derived rather than compared: at either width the bar is
    /// the bare chips' ONE line plus the gap plus the readout's
    /// own line — a readout beside the chips adds nothing at the
    /// wide width, and one squeezed in wraps them at the narrow.
    @Test("the readout sits on its own line under the chips")
    func readoutTakesItsOwnLine() throws {
        // The chips' titles are translated text (#740).
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let name = ShortcutsJumpBar.shownName(
            String(repeating: "W", count: 40)
        )
        let readout = "Editing the \u{201C}\(name)\u{201D} layer"
        let line = try #require(
            ImageRenderer(
                content: Text(readout).font(.callout).fixedSize()
            ).nsImage
        ).size.height
        let wideBare = try barHeight(readout: nil, width: 2000)
        for width: CGFloat in [2000, 700] {
            let bare = try barHeight(readout: nil, width: width)
            // Premise: bare, the chips still fit one line here.
            #expect(bare == wideBare)
            let shown = try barHeight(readout: readout, width: width)
            let expected = bare + ShortcutsJumpBar.spacing + line
            #expect(abs(shown - expected) < 1, "width \(width)")
        }
    }

    /// Centred, by owner ruling (amendment 5): every wrapped line
    /// of chips and the readout under them. Shape, not value — the
    /// one flow layout places the line by its alignment, the bar
    /// asks it for `.center`, and the readout centres its lines.
    @Test("the chips and the readout are centred")
    func chipsAreCentred() throws {
        let slack: CGFloat = 40
        #expect(
            FlowLayout.lineOffset(100, in: 100 + slack, alignment: .center)
                == slack / 2
        )
        #expect(
            FlowLayout.lineOffset(100, in: 100 + slack, alignment: .leading)
                == 0
        )
        // A line wider than the layout starts at its edge.
        #expect(
            FlowLayout.lineOffset(200, in: 100, alignment: .center) == 0
        )
        let bar = try Self.source(
            "Components/Keybindings/ShortcutsJumpBar.swift"
        )
        #expect(
            bar.contains("FlowLayout(spacing:Self.spacing,alignment:.center)")
        )
        #expect(
            bar.contains(
                "VStack(alignment:.center,spacing:Self.spacing){chips"
                    + "ifletshownReadout{readoutText(shownReadout)"
                    + ".multilineTextAlignment(.center)"
            )
        )
        #expect(!bar.contains("ViewThatFits"))
        let flow = try Self.source("FlowLayout.swift")
        // The offset is applied to every placed item.
        #expect(flow.contains("x:bounds.minX+lead+item.x"))
        #expect(flow.contains("letlead=Self.lineOffset(row.width,"))
    }

    private static func source(_ path: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/\(path)"
                    ),
                encoding: .utf8
            )
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
    }
}
