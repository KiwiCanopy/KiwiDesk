import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Home card's shelf picture draws the pocket as a section only
/// where the engine does: beside a bar shown at rest, never beside an
/// Auto bar a reveal brings (#3432).
@Suite("Home card pocket section (#3432)")
@MainActor
struct HomeCardPocketSectionTests {
    private func tile(_ visibility: ShelfVisibility) -> HomeCardBarsTile {
        var settings = TilingSettings()
        settings.spaceBarStyle.visibility = visibility
        // The App Bar on an edge of its own, so the Space Bar alone
        // decides the pocket's edge.
        settings.appBarStyle.edge = .bottom
        settings.kiwishelf.pocketEdge = settings.spaceBarStyle.edge
        return HomeCardBarsTile(settings: settings, pocketStands: true)
    }

    @Test("beside an Auto bar the picture draws no pocket section")
    func autoDrawsNoSection() {
        let edge = TilingSettings().spaceBarStyle.edge
        // Control: beside an Always bar it is a section.
        #expect(tile(.always).pocketIsSection(on: edge))
        #expect(!tile(.auto).pocketIsSection(on: edge))
    }
}
