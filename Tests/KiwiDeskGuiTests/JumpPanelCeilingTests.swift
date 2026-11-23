import AppKit
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// KiwiHub stands inside each side's ceiling (#2309, #3570): the
/// RENDERED panel, field, dividers, footer and the worst list a side
/// draws, measured as AppKit sizes it, from a model built as the
/// controller builds it. A side's width is its own: the field row's
/// on Windows, its columns' on a tall Shortcuts sheet.
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

    private let room = JumpPanelController.room(
        visible: CGRect(x: 0, y: 0, width: 1440, height: 900),
        area: CGRect(x: 0, y: 0, width: 1440, height: 900)
    )

    /// Six eight-row groups: past one column's room on a 900 pt
    /// screen.
    private static let tallSheet = ShortcutsReference(
        layerName: KeyLayer.defaultName,
        controls: (1...6).map { group in
            ShortcutSubgroup(
                title: "Group \(group)",
                rows: (1...8).map {
                    ShortcutRow(
                        id: "\(group).\($0)",
                        label: "Row \(group).\($0)",
                        combo: "⌃⌥X"
                    )
                }
            )
        },
        inactive: [],
        desktopAway: [],
        apps: [],
        custom: []
    )

    private func rendered(
        _ scope: JumpScope,
        sheet: ShortcutsReference? = nil
    ) -> (JumpModel, CGSize) {
        let model = JumpModel(
            snapshot: crowdedSnapshot(),
            icons: [:],
            rowCap: JumpPanelController.rowCap,
            room: room
        )
        model.loadShortcuts = { sheet }
        if scope != .windows { model.setScope(scope) }
        let view = JumpPanelView(
            model: model,
            presence: PanelPresence(reduceMotion: true),
            width: JumpPanelView.width
        )
        let host = NSHostingView(
            rootView: LocaleScopedRoot { view }
                .environmentObject(LocalizationManager.shared)
        )
        // Measured as the panel's own host is (#3570).
        host.sizingOptions = JumpPanelController.hostingSizing
        return (model, host.fittingSize)
    }

    @Test("every side renders inside its own ceiling")
    func everySideFits() {
        LocalizationManager.shared.select("en")
        for scope in JumpScope.allCases {
            let height = rendered(scope, sheet: Self.tallSheet).1.height
            // AppKit rounds the drawn height up to a whole point.
            let ceiling = room.height(JumpPanelRoom.fit(of: scope))
                .rounded(.up)
            #expect(height > JumpPanelView.fieldHeight, "\(scope)")
            #expect(height <= ceiling, "\(scope) stands \(height) pt")
        }
    }

    /// The panel's host keeps no window size of its own and still
    /// reports a size to open at: an empty option set read zero and
    /// opened KiwiHub at no size (owner, 2026-11-23).
    @Test("the panel's host reports a size to open at")
    func hostReportsASize() {
        LocalizationManager.shared.select("en")
        let options = JumpPanelController.hostingSizing
        #expect(!options.contains(.minSize))
        #expect(!options.contains(.maxSize))
        for scope in JumpScope.allCases {
            let size = rendered(scope, sheet: Self.tallSheet).1
            #expect(size.width >= JumpPanelRoom.fieldWidth, "\(scope)")
            #expect(size.height > JumpPanelView.fieldHeight, "\(scope)")
        }
    }

    /// The root takes the side's width: the window glides to it on
    /// ⇥ while the field row stays 720 pt (#3570).
    @Test("each side renders at its own width")
    func sidesTakeTheirWidth() {
        LocalizationManager.shared.select("en")
        let (windows, compact) = rendered(.windows)
        #expect(compact.width == windows.sideWidth)
        #expect(compact.width == JumpPanelRoom.fieldWidth)
        let (shortcuts, wide) = rendered(.shortcuts, sheet: Self.tallSheet)
        #expect(shortcuts.shortcutColumns.columns.count > 1)
        #expect(wide.width == shortcuts.sideWidth)
        #expect(wide.width > JumpPanelRoom.fieldWidth)
    }
}
