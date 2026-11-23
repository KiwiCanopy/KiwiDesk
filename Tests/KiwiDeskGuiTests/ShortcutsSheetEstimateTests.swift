import AppKit
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// The column plan estimates a section's height from its parts
/// (#3570 ▸ Ruling 5); this holds the estimate to the section as
/// SwiftUI lays it out, so a retuned row or font cannot cut the
/// sheet at the wrong height unseen. Renders on the main actor, one
/// small view per case.
@Suite("Shortcuts sheet height estimate")
@MainActor
struct ShortcutsSheetEstimateTests {
    private static func rows(_ count: Int) -> [ShortcutRow] {
        (1...count).map {
            ShortcutRow(id: "r\($0)", label: "Row \($0)", combo: "⌃⌥X")
        }
    }

    private func reference(
        controls: Int = 0,
        inactive: Int = 0
    ) -> ShortcutsReference {
        ShortcutsReference(
            layerName: KeyLayer.defaultName,
            controls: controls == 0
                ? []
                : [
                    ShortcutSubgroup(title: "Focus", rows: Self.rows(controls))
                ],
            inactive: inactive == 0 ? [] : Self.rows(inactive),
            desktopAway: [],
            apps: [],
            custom: []
        )
    }

    /// The drawn height of `reference`'s one section at `width`, and
    /// the plan's estimate of it.
    private func heights(
        _ reference: ShortcutsReference,
        width: CGFloat
    ) throws -> (drawn: CGFloat, planned: CGFloat) {
        let view = ShortcutsSheetView(reference: reference, needle: "")
            .frame(width: width)
        let host = NSHostingView(
            rootView: LocaleScopedRoot { view }
                .environmentObject(LocalizationManager.shared)
        )
        let section = try #require(
            ShortcutsSheetView.sections(reference).first
        )
        let planned = ShortcutsSheetView.planned(
            section,
            needle: "",
            width: width
        )
        return (host.fittingSize.height, planned.height)
    }

    @Test("a section of rows is planned as tall as it draws")
    func rowsMatch() throws {
        LocalizationManager.shared.select("en")
        for count in [1, 8] {
            let (drawn, planned) = try heights(
                reference(controls: count),
                width: ShortcutsColumnPlan.columnWidth
            )
            #expect(abs(drawn - planned) <= 4, "\(count): \(drawn) \(planned)")
        }
    }

    /// The caption wraps; the estimate may run a line over, never
    /// under, so a sheet that would scroll is never kept whole.
    @Test("a captioned section is planned no shorter than it draws")
    func captionMatches() throws {
        LocalizationManager.shared.select("en")
        for width: CGFloat in [ShortcutsColumnPlan.columnWidth, 688] {
            let (drawn, planned) = try heights(
                reference(inactive: 3),
                width: width
            )
            #expect(planned >= drawn - 4, "\(width): \(drawn) \(planned)")
            #expect(planned <= drawn + 20, "\(width): \(drawn) \(planned)")
        }
    }
}
