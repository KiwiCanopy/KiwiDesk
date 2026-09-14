import Foundation
import Testing

@testable import KiwiDesk

/// The Mac Checklist's cross-references (#1365) — the value half
/// `CrossReferenceRowSlotTests` registers `MacHabitRow.swift:prose`
/// for, split off because that file sits at the §2.1 ceiling.
@MainActor
@Suite("Mac Checklist cross-reference position")
struct MacChecklistCrossReferenceTests {
    private static let slot = CrossReferenceRow.linkSlot

    /// The Mac Checklist's habits (#1365): one sentence each,
    /// the three naming a KiwiDesk surface placing their link at
    /// the slot, and the two naming none carrying NO slot — a
    /// stray token there would render as a glyph in the plain
    /// `Text` arm. Both halves over the census order list, so a
    /// habit gaining or losing its destination reds here.
    @Test func theHabitProsePlacesItsLink() {
        for row in MacChecklistRowOrder.habits {
            guard case .macChecklist(let key) = row else {
                Issue.record("\(row.id) is not a checklist row")
                continue
            }
            let prose = MacChecklistText.habit(for: key)
            #expect(
                prose.contains(Self.slot)
                    == (key.destination != nil),
                "\(key) mis-places its link"
            )
        }
    }

    /// Every settings caption places its System Settings path at
    /// the slot: `MacSettingRow` splits on it, and a caption
    /// without one would draw the link at the end where no
    /// translation can move it.
    @Test func everyCaptionPlacesItsPath() {
        for row in MacChecklistRowOrder.essentialSettings
            + MacChecklistRowOrder.optionalSettings
        {
            guard case .macChecklist(let key) = row else {
                Issue.record("\(row.id) is not a checklist row")
                continue
            }
            #expect(
                MacChecklistText.caption(for: key).contains(Self.slot),
                "\(key) never places its path"
            )
        }
        #expect(MacChecklistText.unreadable.contains(Self.slot))
    }
}
