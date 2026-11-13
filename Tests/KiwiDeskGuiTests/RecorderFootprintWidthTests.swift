import AppKit
import SwiftUI
import Testing

@testable import KiwiDesk

/// A setting row's footprint is the recorder's width to the point
/// (#3160): a footprint 4 pt narrower put every setting row's
/// "Applies to" 4 pt right of the key rows' column. `@MainActor` for
/// the renderer; four small renders.
@Suite("Recorder footprint width (#3160)")
@MainActor
struct RecorderFootprintWidthTests {
    /// The rendered width; a plain ground, since a hidden view
    /// alone draws nothing to render.
    private func width<V: View>(_ view: V, sides: RecorderSides?) throws
        -> CGFloat
    {
        let sized = view.background(Color.white)
            .environment(\.recorderSides, sides)
            .fixedSize()
        return try #require(ImageRenderer(content: sized).nsImage)
            .size.width
    }

    @Test("the footprint is the recorder's width, sides or none")
    func footprintMatchesTheField() throws {
        let coordinator = RecorderCoordinator()
        for sides in [nil, RecorderSides(hyperKey: nil)] {
            let field = KeyRecorderField(
                name: "Toggle tiling",
                combo: "ctrl+alt+t",
                reading: nil,
                narrowing: nil,
                onRecord: { _ in },
                onClear: {}
            )
            .environmentObject(coordinator)
            let footprint = try width(
                KeyRecorderField.footprint,
                sides: sides
            )
            #expect(footprint > 0)
            #expect(try width(field, sides: sides) == footprint)
        }
    }
}
