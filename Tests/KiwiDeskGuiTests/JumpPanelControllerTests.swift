import Foundation
import Testing

@testable import KiwiDesk

/// The list grows to a third of the screen's visible height, never
/// fewer than 6 rows nor more than 12, and shrinks to fit fewer
/// results (#1875 ▸ Panel). A pick distrusts the dismiss blip.
@Suite("Jump to window panel controller")
@MainActor
struct JumpPanelControllerTests {
    @Test("the row cap is a third of the screen, 6 to 12 rows")
    func rowCap() {
        let row = JumpRowView.height
        #expect(JumpPanelController.rowCap(visibleHeight: 300) == 6)
        #expect(
            JumpPanelController.rowCap(visibleHeight: 3 * row * 8) == 8
        )
        #expect(JumpPanelController.rowCap(visibleHeight: 5000) == 12)
    }

    @Test("the list fits its rows up to the cap")
    func listHeight() {
        let row = JumpRowView.height
        let pad = 2 * JumpPanelView.listPadding
        #expect(
            JumpPanelView.listHeight(rows: 2, hasHeader: false, rowCap: 6)
                == 2 * row + pad
        )
        #expect(
            JumpPanelView.listHeight(rows: 2, hasHeader: true, rowCap: 6)
                == 2 * row + JumpPanelView.headerHeight + pad
        )
        #expect(
            JumpPanelView.listHeight(rows: 40, hasHeader: true, rowCap: 6)
                == 6 * row + pad
        )
    }

    @Test("a pick distrusts the dismiss blip unless it is our own")
    func pickHandoff() {
        #expect(JumpPanelController.distrustsHandoff(pick: 42, own: 7))
        #expect(!JumpPanelController.distrustsHandoff(pick: 7, own: 7))
    }
}
