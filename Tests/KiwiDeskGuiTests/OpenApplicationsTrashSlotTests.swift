import AppKit
import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk

/// A rule row's trash keeps ONE width whichever form it draws, and
/// a trash-less row beside trash rows holds that width, so a
/// card's trailing reach and key columns line up — the Open
/// applications card's KiwiDesk rows sat one trash-width off.
///
/// Main-actor spend: three `NSHostingView` fitting sizes, once.
@Suite("Rule trash column width")
@MainActor
struct OpenApplicationsTrashSlotTests {
    private func width(_ view: some View) -> CGFloat {
        NSHostingView(rootView: view).fittingSize.width
    }

    private var shared: RuleReachReading {
        RuleReachReading(
            editing: "A",
            loaded: "A",
            profiles: ["A", "B"],
            unreadable: [],
            shared: true,
            hasShared: true,
            users: ["A", "B"],
            own: [:],
            ownIsShared: [],
            leftOut: []
        )
    }

    @Test("both trash forms and the empty slot are one width")
    func oneWidth() {
        let plain = width(AppRuleDeleteButton(help: "x") { _ in })
        let menu = width(
            AppRuleDeleteButton(help: "x", sharedFrom: shared) { _ in }
        )
        let slot = width(AppRuleDeleteButton.slot)
        #expect(plain > 0)
        #expect(plain == menu)
        #expect(slot == menu)
    }

    private func source(_ name: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Keybindings"
            )
            .appendingPathComponent(name)
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        return text.split(whereSeparator: \.isWhitespace).joined()
    }

    /// The card asks, and the row ends in the slot right after its
    /// key field, where an app row's trash stands.
    @Test("the KiwiDesk rows hold the slot in the apps card")
    func kiwiDeskRowsHoldTheSlot() throws {
        let group = try source("KeybindingAppGroup.swift")
        #expect(
            group.contains(
                "KiwiDeskKeyRows(model:model,bindings:$bindings,"
                    + "expander:expander)"
                    + ".environment(\\.keybindingReservesTrashSlot,true)"
            )
        )
        let row = try source("KeybindingNavRow.swift")
        #expect(
            row.contains(
                "onClear:clear)ifreservesTrashSlot{"
                    + "AppRuleDeleteButton.slot}}"
            )
        )
        #expect(
            row.contains(
                "@Environment(\\.keybindingReservesTrashSlot)"
                    + "privatevarreservesTrashSlot"
            )
        )
    }
}
