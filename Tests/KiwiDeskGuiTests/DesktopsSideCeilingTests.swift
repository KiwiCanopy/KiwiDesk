import AppKit
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// The Desktops side's two screen rows stand inside KiwiHub's one
/// ceiling (#1229, the 488 pt the ruling raised it to): the
/// RENDERED panel, field, footer and both rows of cards, measured
/// as AppKit sizes it.
@Suite("Desktops side height")
@MainActor
struct DesktopsSideCeilingTests {
    @Test("two screen rows of cards fit under the ceiling")
    func twoRowsFit() {
        LocalizationManager.shared.select("en")
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let model = JumpModel(
            snapshot: JumpSnapshot(entries: [], here: nil, hereIcon: nil),
            icons: [:],
            rowCap: JumpPanelController.rowCap,
            sheetCap: JumpPanelController.sheetCap(
                visible: visible,
                area: visible
            )
        )
        model.loadDesktops = { DesktopsStateTests.overview() }
        model.setScope(.desktops)
        let view = JumpPanelView(
            model: model,
            presence: PanelPresence(),
            width: JumpPanelView.width
        )
        let host = NSHostingView(
            rootView: LocaleScopedRoot { view }
                .environmentObject(LocalizationManager.shared)
        )
        let height = host.fittingSize.height
        // Both rows are drawn whole, not scrolled to fit.
        #expect(
            height >= 2 * DesktopsSideView.rowHeight
                + JumpPanelView.fieldHeight,
            "stands \(height) pt"
        )
        #expect(height <= JumpPanelController.maxPanelHeight, "\(height) pt")
    }
}
