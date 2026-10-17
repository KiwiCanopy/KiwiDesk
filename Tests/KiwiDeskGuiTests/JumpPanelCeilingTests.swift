import AppKit
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// KiwiHub stands no taller than its one ceiling on any side
/// (#2309): the RENDERED panel, field, dividers, footer and the
/// worst list a side draws, measured as AppKit sizes it.
@Suite("KiwiHub height ceiling")
@MainActor
struct JumpPanelCeilingTests {
    /// Shown, minimized and hidden rows, so both section headers
    /// fall inside the capped list.
    private func crowdedSnapshot() -> JumpSnapshot {
        var entries: [JumpEntry] = []
        for id in 1...5 {
            entries.append(JumpListTests.row(UInt32(id), "App \(id)"))
        }
        for id in 6...8 {
            entries.append(
                JumpListTests.row(
                    UInt32(id),
                    "App \(id)",
                    status: .minimized
                )
            )
        }
        for id in 9...40 {
            entries.append(
                JumpListTests.row(UInt32(id), "App \(id)", hidden: true)
            )
        }
        return JumpSnapshot(entries: entries, here: nil, hereIcon: nil)
    }

    private func renderedHeight(_ scope: JumpScope) -> CGFloat {
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let model = JumpModel(
            snapshot: crowdedSnapshot(),
            icons: [:],
            rowCap: JumpPanelController.rowCap,
            sheetCap: JumpPanelController.sheetCap(
                visible: visible,
                area: visible
            )
        )
        if scope != .windows { model.setScope(scope) }
        let view = JumpPanelView(
            model: model,
            settings: TilingSettings(),
            liquidGlass: false,
            presence: PanelPresence(),
            width: JumpPanelView.width
        )
        let host = NSHostingView(
            rootView: LocaleScopedRoot { view }
                .environmentObject(LocalizationManager.shared)
        )
        return host.fittingSize.height
    }

    @Test("every side renders inside the ceiling")
    func everySideFits() {
        LocalizationManager.shared.select("en")
        for scope in JumpScope.allCases {
            let height = renderedHeight(scope)
            #expect(height > JumpPanelView.fieldHeight, "\(scope)")
            #expect(
                height <= JumpPanelController.maxPanelHeight,
                "\(scope) stands \(height) pt"
            )
        }
    }
}
