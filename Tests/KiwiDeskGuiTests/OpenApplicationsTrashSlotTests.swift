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
/// Main-actor spend: six `NSHostingView` fitting sizes, once.
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
        #expect(slot == AppRuleDeleteButton.columnWidth)
    }

    /// Every form takes the one fixed width, and the slot is no
    /// control: a hidden item-less menu sized itself narrower than
    /// the trash in a live window, which `fittingSize` above cannot
    /// see (Pocket and Open applications, owner 2026-11-08).
    @Test("the trash column is one fixed width, the slot no control")
    func columnIsFixed() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Common/"
                    + "AppRuleIdentity.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace).joined()
        #expect(
            source.contains(
                "}}.frame(width:Self.columnWidth)}staticvarslot:someView{"
                    + "Color.clear.frame(width:columnWidth,height:1)"
            )
        )
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

    /// A setting row in a card with trash rows holds the slot too,
    /// so its control ends where the recorders do (#2922).
    @Test("a setting row holds the slot when its card asks")
    func settingRowHoldsTheSlot() {
        let row = ShortcutSettingRow(title: "x", help: "x") {
            Text("x")
        }
        let bare = width(row)
        let held = width(
            row.environment(\.keybindingReservesTrashSlot, true)
        )
        let slot = width(AppRuleDeleteButton.slot)
        #expect(slot > 0)
        #expect(held - bare >= slot)
    }

    /// The key rows share one ask (Holds retired, #2978); the
    /// per-app rows, which draw their own trash, stay outside it. The ask
    /// is the card's one spelling of the key, so no row inside it
    /// sets it back.
    @Test("the Pocket card's key rows hold the slot")
    func pocketHoldsRowHoldsTheSlot() throws {
        let group = try source("PocketGroup.swift")
        #expect(
            group.contains(
                "Group{ForEach(ShortcutsRowOrder.pocketAtRest"
            )
        )
        #expect(
            group.contains(
                "}}.environment(\\.keybindingReservesTrashSlot,true)"
                    + "PocketAppRows("
            )
        )
        let asks = group.components(
            separatedBy: "keybindingReservesTrashSlot"
        )
        #expect(asks.count == 2, "one ask, nothing overriding it")
    }
}
