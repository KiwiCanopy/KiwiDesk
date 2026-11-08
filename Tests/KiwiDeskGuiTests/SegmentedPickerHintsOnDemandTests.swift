import AppKit
import SwiftUI
import Testing

@testable import KiwiDesk

/// KiwiHub's side switch draws titles only, a side's chord standing
/// in for its title while ⌘ is held or the pointer is on it, in a
/// width that never moves (#1229 ▸ Tab bar). `@MainActor` for the
/// renderer; four small renders.
@Suite("Segmented picker hints on demand")
@MainActor
struct SegmentedPickerHintsOnDemandTests {
    private let options = [("Windows", 0), ("View", 1)]
    /// One chord wider than its title, one narrower.
    private let hints = [0: "⌃⌥J", 1: "⌃⌥⌘⇧F12"]

    private func width(onDemand: Bool, shown: Bool) throws -> CGFloat {
        let picker = SegmentedPicker(
            reservesWeight: true,
            hints: hints,
            hintsOnDemand: onDemand,
            showsHints: shown,
            selection: .constant(0),
            options: options
        )
        .fixedSize()
        return try #require(ImageRenderer(content: picker).nsImage)
            .size.width
    }

    @Test("showing the chords never changes the switch's width")
    func widthHolds() throws {
        let rest = try width(onDemand: true, shown: false)
        #expect(try width(onDemand: true, shown: true) == rest)
    }

    /// The reserve is the wider of title and chord per segment, never
    /// their sum, which is what the inline strip pays.
    @Test("the on-demand strip is narrower than the inline one")
    func narrowerThanInline() throws {
        let inline = try width(onDemand: false, shown: false)
        #expect(try width(onDemand: true, shown: false) < inline)
    }

    @Test("a chord shows on demand only")
    func showsOnDemand() {
        func picker(onDemand: Bool, shown: Bool) -> SegmentedPicker<Int> {
            SegmentedPicker(
                hints: hints,
                hintsOnDemand: onDemand,
                showsHints: shown,
                selection: .constant(0),
                options: options
            )
        }
        #expect(!picker(onDemand: true, shown: false).showsHint(at: 0))
        #expect(picker(onDemand: true, shown: true).showsHint(at: 1))
        // Every other strip keeps its hints drawn.
        #expect(picker(onDemand: false, shown: false).showsHint(at: 0))
    }
}
