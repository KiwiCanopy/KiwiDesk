import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A key whose Desktop no screen shows does nothing when pressed,
/// so the Shortcuts sheet lifts it out of its group into the
/// Unavailable band at the column's end, beside its caption.
@Suite("Shortcuts unavailable band", .serialized)
@MainActor
struct ShortcutsUnavailableBandTests {
    private func desktopLua(_ number: Int) -> String {
        KeybindingCatalog.goToDesktop([number])[0].lua
    }

    private func build(_ desktops: [Int]) -> ShortcutsReference {
        ShortcutsReferenceBuilder.build(
            layer: KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [1, 6].map {
                    KeyBinding(
                        combo: "ctrl+alt+\($0)",
                        lua: desktopLua($0),
                        kind: .navigation
                    )
                }
            ),
            spaces: ["1"],
            spaceIcons: [:],
            desktops: desktops,
            resizeStep: 50,
            layerNames: [KeyLayer.defaultName]
        )
    }

    @Test("a Desktop no screen shows leaves its group for the band")
    func awayDesktopLeavesItsGroup() {
        LocalizationManager.shared.select("en")
        let reference = build([1, 2])
        let grouped = reference.controls.flatMap(\.rows)
        #expect(reference.desktopAway.map(\.label) == ["Go to Desktop 6"])
        let marked = reference.desktopAway.allSatisfy { $0.unavailable }
        #expect(marked)
        #expect(!grouped.contains { $0.unavailable })
        #expect(grouped.contains { $0.label == "Go to Desktop 1" })
    }

    @Test("with every Desktop present the band is empty")
    func presentDesktopsStayGrouped() {
        LocalizationManager.shared.select("en")
        let reference = build([1, 2, 3, 4, 5, 6])
        #expect(reference.desktopAway.isEmpty)
        #expect(
            reference.controls.flatMap(\.rows).contains {
                $0.label == "Go to Desktop 6"
            }
        )
    }

    /// The band is data the view may simply not draw, so the
    /// drawing is needled at its use site
    /// (`ShortcutsInactiveBandTests` ▸ `theViewDrawsTheBand`).
    @Test("the panel draws the band with its caption")
    func theViewDrawsTheBand() throws {
        let path = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Shortcuts/ShortcutsSheetView.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: path, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        #expect(
            source.contains(
                "rows:reference.desktopAway,"
                    + "caption:KeybindingCatalog.desktopAwayCaption"
            )
        )
    }
}
