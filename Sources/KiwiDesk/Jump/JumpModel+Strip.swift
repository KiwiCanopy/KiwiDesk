import Foundation
import KiwiDeskCore

/// The Windows side's list words, and its app strip (#3135): ← →
/// walk the strip while the field is empty, a click picks a tile,
/// and the last-app opener lands it on the app of the window used
/// just before. VoiceOver hears the tile and the row it selects.
extension JumpModel {
    /// What VoiceOver hears when the results change.
    var resultsSpoken: String {
        guard list.results.isEmpty else {
            return L(
                "jump.ax.results",
                "Results: %1$d",
                list.results.count
            )
        }
        return emptyText
    }

    /// The line an empty list shows: an app the strip is on that
    /// lists no window says so (#3135).
    var emptyText: String {
        if list.stripApp != nil {
            return L("jump.empty.app", "No windows")
        }
        return list.snapshot.entries.isEmpty
            ? L("jump.empty.other", "No other windows")
            : L("jump.empty.no_match", "No open windows match")
    }

    /// One tile along the strip, wrapping on a fresh press (#2897).
    func stepTile(_ delta: Int, wrap: Bool) {
        let before = list.tile
        moveStrip { $0.stepTile(delta, wrap: wrap) }
        if list.tile != before { announceTile() }
    }

    /// A click on tile `index`; a tile the query dims takes none.
    func clickTile(_ index: Int) {
        guard scope == .windows, list.tileMatches(index),
            index != list.tile
        else { return }
        moveStrip { $0.pickTile(index) }
        announceTile()
    }

    /// Reopens the app the strip is on where it lists no window —
    /// ↩, a click or VoiceOver on its "No windows" row (#1840).
    func reopenStripApp() {
        guard list.results.isEmpty, let app = list.stripApp,
            app.bundleID != nil
        else { return }
        onReopen(app)
    }

    /// The last-app opener: the strip on row 1's app, row 1 kept.
    func openOnLastApp() {
        guard scope == .windows else { return }
        moveStrip { $0.pickLastApp() }
    }

    /// The tile's name and what the list now selects.
    private func announceTile() {
        let name = list.stripApp.map(\.name) ?? JumpStripText.allName
        let row = list.selected.map { JumpRowText.spoken($0.entry) }
        onAnnounce(JumpStripText.moved(tile: name, row: row ?? emptyText))
    }
}
