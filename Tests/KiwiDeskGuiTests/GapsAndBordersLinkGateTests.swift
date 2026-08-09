import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The one-width link's gate (#754), split from
/// `GapsAndBordersGateTests` so neither file crosses the size
/// ceiling. Two questions the rest of that suite cannot ask:
/// what the link greys, and where it sits in each row's arm
/// order.
@Suite("Gaps & Borders width link gate")
struct GapsAndBordersLinkGateTests {
    private func gates(
        linkedWidth: Bool,
        _ overrides: (inout TilingSettings) -> Void = { _ in }
    ) -> GapsBordersGates {
        var s = TilingSettings()
        overrides(&s)
        return GapsBordersGates(
            settings: s,
            linkedWidth: linkedWidth
        )
    }

    /// The one-width link (#754) greys exactly the three
    /// follower rows — the ring's corner and the two drag
    /// widths — and nothing else in the area.
    @Test("the one-width link greys the three followers")
    func linkGreysItsFollowers() {
        let followers: [SettingKey] = [
            .borders(.borderCorner),
            .borders(.dragGhostBorderWidth),
            .borders(.dragDropZoneBorderWidth),
        ]
        let linked = gates(linkedWidth: true)
        let loose = gates(linkedWidth: false)
        for key in followers {
            #expect(linked.inertReason(for: key) == .widthLinked)
            #expect(loose.inertReason(for: key) == nil)
        }
        // Nothing ELSE moves with the link: a resolver that
        // returned `.widthLinked` from a shared arm would grey
        // the Border/Fill toggles too, and unlinking would then
        // be offered as the fix for a row the link never owned.
        for key in SettingKey.allCases
        where key.placement.area == .gapsAndBorders
            && !followers.contains(key)
        {
            #expect(
                linked.inertReason(for: key)
                    == loose.inertReason(for: key),
                "\(key.id) changed with the width link"
            )
        }
    }

    /// The link speaks LAST. A width whose column is off, or
    /// whose Border toggle is off, is dead for that reason —
    /// blaming the link there would offer a fix that un-greys
    /// nothing, and the corner picker inside a dark ring block
    /// would shadow the block's own sentence.
    @Test("a column's own switches outrank the link")
    func columnSwitchesOutrankTheLink() {
        #expect(
            gates(linkedWidth: true) { $0.dragGhost.enabled = false }
                .inertReason(for: .borders(.dragGhostBorderWidth))
                == .visualOff
        )
        #expect(
            gates(linkedWidth: true) { $0.dragGhost.border = false }
                .inertReason(for: .borders(.dragGhostBorderWidth))
                == .visualBorderOff
        )
        #expect(
            gates(linkedWidth: true) {
                $0.dragDropZone.enabled = false
            }
            .inertReason(for: .borders(.dragDropZoneBorderWidth))
                == .visualOff
        )
        #expect(
            gates(linkedWidth: true) {
                $0.dragDropZone.border = false
            }
            .inertReason(for: .borders(.dragDropZoneBorderWidth))
                == .visualBorderOff
        )
        #expect(
            gates(linkedWidth: true) {
                $0.borderStyle.enabled = false
            }
            .inertReason(for: .borders(.borderCorner)) == nil
        )
    }
}
