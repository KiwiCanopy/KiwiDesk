import CoreGraphics
import Foundation
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// The jump bar's layer readout (#1520), split from
/// `ShortcutsJumpTests` at the §2.1 ceiling: it never elides the
/// sentence — a long name is cut inside it, and a readout that
/// does not fit beside the chips takes a line of its own.
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

    /// Where the readout does not fit beside the chips it takes a
    /// line of its own instead of eliding; where it fits, it adds
    /// no line. Derived rather than compared: at the narrow width
    /// the bar is the bare chips' ONE line plus the gap plus the
    /// readout's own line — a readout squeezed in beside the chips
    /// wraps them instead, which a bare "taller" cannot tell apart.
    @Test("the readout moves under the chips rather than eliding")
    func readoutDropsALine() throws {
        // The chips' titles are translated text (#740).
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let name = ShortcutsJumpBar.shownName(
            String(repeating: "W", count: 40)
        )
        let readout = "Editing the \u{201C}\(name)\u{201D} layer"
        let wide = try barHeight(readout: readout, width: 2000)
        let wideBare = try barHeight(readout: nil, width: 2000)
        #expect(wide == wideBare)
        let narrow = try barHeight(readout: readout, width: 700)
        let narrowBare = try barHeight(readout: nil, width: 700)
        // Premise: bare, the chips still fit one line here.
        #expect(narrowBare == wideBare)
        let line = try #require(
            ImageRenderer(
                content: Text(readout).font(.subheadline).fixedSize()
            ).nsImage
        ).size.height
        let expected = narrowBare + ShortcutsJumpBar.spacing + line
        #expect(abs(narrow - expected) < 1)
    }
}
