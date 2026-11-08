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
        // Both rows stand whole: the cap the side is handed does not
        // cut them.
        let cap = model.sheetCap
        let whole = DesktopsSideView.height(rows: 2, cap: .infinity)
        #expect(DesktopsSideView.height(rows: 2, cap: cap) == whole)
        #expect(height >= whole + JumpPanelView.fieldHeight, "\(height)")
        #expect(height <= JumpPanelController.maxPanelHeight, "\(height)")
    }
}
