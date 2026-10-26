import Foundation

/// The defaults a release added after the first-run seed, by
/// generation (#2211). A seed carries every generation, so a
/// fresh install has nothing to top up; an install that predates
/// a generation gets its rows once, where free.
extension DefaultKeybindings {
    /// The newest generation. A release that adds a default row
    /// bumps it and lists the rows in `rows(ofGeneration:)`.
    public static let newestGeneration = 8

    /// The rows generation `number` introduced, built from today's
    /// rows: an install not yet topped up gets the current chord
    /// even where a later release re-chorded one.
    public static func rows(ofGeneration number: Int) -> [KeyBinding] {
        switch number {
        // 2.3.0: the Space steps and the Space history (#1655).
        case 1: spaceStepRows() + spaceHistoryRows()
        // 3.0.0: the layout keys (#453, #762).
        case 2: [nextLayoutRow(), previousLayoutRow(), layoutPickerRow()]
        // 3.0.0: Jump to window (#1875), a generation of its own
        // since installs had already taken 2 from release/3.0.0.
        case 3: [jumpToWindowRow()]
        // 3.0.0: KiwiVision (#2103).
        case 4: [kiwiVisionRow()]
        // 3.1.0: Reset sizes in this Space (#2303).
        case 5: [resetSizesRow()]
        // The bars' shortcuts (#761).
        case 6: barRevealRows()
        // Maximize (#2448).
        case 7: [maximizeRow()]
        // Pocket (#2446).
        case 8: [pocketRow()]
        default: []
        }
    }

    /// The rows of every generation above `mark` whose action no
    /// row in `existing` binds and whose chord is free, each on
    /// `base` (#2460). Additive, like `desktopTopUp`: a row the user
    /// deleted after its generation was offered stays deleted.
    public static func generationTopUp(
        existing: [KeyBinding],
        above mark: Int,
        base: ShortcutBase
    ) -> [KeyBinding] {
        guard mark < newestGeneration else { return [] }
        // As registered: a Hyper row holds its bare chord (#1870).
        var taken = Set(
            existing.compactMap { KeyCombo.parse($0.combo)?.registered }
        )
        var bound = Set(existing.map(\.lua))
        var added: [KeyBinding] = []
        for number in (max(mark, 0) + 1)...newestGeneration {
            for seeded in rows(ofGeneration: number) {
                let row = base.rebased(seeded)
                guard !bound.contains(row.lua),
                    let combo = KeyCombo.parse(row.combo),
                    taken.insert(combo.registered).inserted
                else { continue }
                bound.insert(row.lua)
                added.append(row)
            }
        }
        return added
    }
}
