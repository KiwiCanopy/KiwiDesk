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

    /// Lays the sheet out again for what it shows now.
    func planShortcuts() {
        guard let sheet = shortcuts, let shown = sheet.shown,
            !shown.isEmpty
        else {
            shortcutColumns = .empty
            return
        }
        let inset = JumpShortcutsView.kiwiHubInset
        let view = ShortcutsSheetView(reference: shown, needle: sheet.needle)
        let sections = view.sections(shown).map {
            ShortcutsSheetView.planned(
                $0,
                needle: sheet.needle,
                width: ShortcutsColumnPlan.columnWidth
            )
        }
        shortcutColumns = ShortcutsColumnPlan(
            sections: sections,
            cap: sheetCap - 2 * JumpShortcutsView.kiwiHubVerticalInset,
            columns: ShortcutsColumnPlan.columnsFitting(
                room.widest,
                inset: inset
            )
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
