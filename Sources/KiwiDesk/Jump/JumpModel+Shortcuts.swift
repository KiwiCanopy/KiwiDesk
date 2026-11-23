import Foundation
import KiwiDeskCore

/// A scroll the Shortcuts side's keys ask of its sheet: ↑ ↓ a line,
/// Page Up / Page Down a page. `serial` makes each press a change.
struct SheetScroll: Equatable {
    var serial = 0
    var lines = 0
    var pages = 0
}

/// The Shortcuts side of the key panel (#2246): its keys, its
/// query, the scroll its keys drive and its column plan (#3570 ▸
/// Ruling 5). A reference sheet: no selection, so ↩ and the ⌘
/// numbers do nothing here, and ← → stay with the field's text.
extension JumpModel {
    /// Re-reads the sheet, keeping the query.
    func reloadShortcuts() {
        guard let old = shortcuts else { return }
        var fresh = ShortcutsSheet(reference: loadShortcuts())
        fresh.setQuery(old.query)
        shortcuts = fresh
        onResultsChange()
    }

    func setShortcutQuery(_ query: String) {
        guard shortcuts != nil else { return }
        shortcuts?.setQuery(query)
        onResultsChange()
        onAnnounce(shortcutsSpoken)
    }

    func handleShortcuts(_ key: JumpKey) {
        switch key {
        case .step(let delta):
            scrollSheet(lines: delta)
        case .page(let direction):
            scrollSheet(pages: direction)
        case .settings:
            onEditShortcuts()
        case .escape:
            if shortcuts?.query.isEmpty ?? true {
                onClose()
            } else {
                setShortcutQuery("")
            }
        case .pick, .swapHere, .quick, .quickSwap, .stepScope, .side,
            .keep, .swallow, .dead, .openSpace, .leaveSpace, .pickUp,
            .follow:
            break
        }
    }

    private func scrollSheet(lines: Int = 0, pages: Int = 0) {
        sheetScroll = SheetScroll(
            serial: sheetScroll.serial + 1,
            lines: lines,
            pages: pages
        )
    }

    /// Lays the sheet out again for what it shows now: across the
    /// column count the side opened with, which the first plan after
    /// entering sets and typing never changes (#3570 ▸ Ruling 5).
    func planShortcuts() {
        guard let sheet = shortcuts, let shown = sheet.shown,
            !shown.isEmpty
        else {
            shortcutColumns = .empty
            return
        }
        let all = ShortcutsSheetView.sections(shown, needle: sheet.needle)
        let flowing = all.filter { !$0.closes }
        func planned(
            _ sections: [ShortcutsSheetView.Section],
            at width: CGFloat
        ) -> [ShortcutsColumnPlan.Section] {
            sections.map {
                ShortcutsSheetView.planned(
                    $0,
                    needle: sheet.needle,
                    width: width
                )
            }
        }
        let inset = JumpShortcutsView.kiwiHubInset
        let column =
            ShortcutsColumnPlan.columnPitch - ShortcutsSheetView.columnGap
        // One column is judged as it draws: at the field row's
        // width, the closing section with it.
        let single = room.fieldWidth - 2 * inset
        let count =
            shortcutCount
            ?? ShortcutsColumnPlan.count(
                single: planned(flowing, at: single),
                closing: planned(all.filter(\.closes), at: single)
                    .map(\.height).reduce(0, +),
                cap: sheetCap - 2 * JumpShortcutsView.kiwiHubVerticalInset,
                limit: ShortcutsColumnPlan.columnsFitting(
                    room.widest,
                    inset: inset,
                    gap: ShortcutsSheetView.columnGap
                )
            )
        shortcutCount = count
        shortcutColumns = ShortcutsColumnPlan(
            sections: planned(
                flowing,
                at: count > 1 ? column : single
            ),
            columns: count
        )
    }

    /// What VoiceOver hears when the query changes.
    var shortcutsSpoken: String {
        guard let shortcuts else { return "" }
        guard shortcuts.matchCount > 0 else {
            return L("shortcuts.panel.no_match", "No shortcuts match")
        }
        return L("jump.ax.results", "Results: %1$d", shortcuts.matchCount)
    }
}
