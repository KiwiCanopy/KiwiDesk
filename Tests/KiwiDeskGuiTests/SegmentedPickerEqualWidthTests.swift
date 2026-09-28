import AppKit
import SwiftUI
import Testing

@testable import KiwiDesk

/// A segmented strip left at its natural width shows every label
/// whole, at one width whatever is selected (#1726): the segments
/// share one width, sized by the widest label at the selected
/// weight. `@MainActor` for the renderer; a few small renders.
@Suite("Segmented picker natural width")
@MainActor
struct SegmentedPickerEqualWidthTests {
    private let options = [
        ("A much longer option label", 0),
        ("Short", 1),
    ]

    private func width(selected: Int) throws -> CGFloat {
        let picker = SegmentedPicker(
            hugsLabels: true,
            selection: .constant(selected),
            options: options
        )
        .fixedSize()
        return try #require(ImageRenderer(content: picker).nsImage)
            .size.width
    }

    private func textWidth(_ text: String) -> CGFloat {
        let font = NSFont.systemFont(
            ofSize: NSFont.systemFontSize,
            weight: .semibold
        )
        return (text as NSString).size(withAttributes: [.font: font])
            .width
    }

    @Test("the width does not move with the selection")
    func widthIsStable() throws {
        #expect(try width(selected: 0) == width(selected: 1))
    }

    /// Two equal segments, each wide enough for the longest label
    /// at the selected weight — never the sum of the two labels.
    @Test("each segment fits the longest label")
    func segmentsFitTheLongest() throws {
        let longest = textWidth(options[0].0)
        #expect(try width(selected: 1) >= 2 * longest)
    }
}
