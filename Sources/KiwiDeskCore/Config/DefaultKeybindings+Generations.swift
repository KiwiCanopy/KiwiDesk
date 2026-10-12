import Foundation

/// The defaults a release added after the first-run seed, by
/// generation (#2211). A seed carries every generation, so a
/// fresh install has nothing to top up; an install that predates
/// a generation gets its rows once, where free.
extension DefaultKeybindings {
    /// The newest generation. A release that adds a default row
    /// bumps it and lists the rows in `rows(ofGeneration:)`.
    public static let newestGeneration = 1

    /// The rows generation `number` introduced, built from today's
    /// rows: an install not yet topped up gets the current chord
    /// even where a later release re-chorded one.
    public static func rows(ofGeneration number: Int) -> [KeyBinding] {
        switch number {
        // 2.3.0: the Space steps and the Space history (#1655).
        case 1: spaceStepRows() + spaceHistoryRows()
        default: []
        }
    }

    /// The rows of every generation above `mark` whose action no
    /// row in `existing` binds and whose chord is free. Additive,
    /// like `desktopTopUp`: a row the user deleted after its
    /// generation was offered stays deleted.
    public static func generationTopUp(
        existing: [KeyBinding],
        above mark: Int
    ) -> [KeyBinding] {
        guard mark < newestGeneration else { return [] }
        var taken = Set(existing.compactMap { KeyCombo.parse($0.combo) })
        var bound = Set(existing.map(\.lua))
        var added: [KeyBinding] = []
        for number in (max(mark, 0) + 1)...newestGeneration {
            for row in rows(ofGeneration: number) {
                guard !bound.contains(row.lua),
                    let combo = KeyCombo.parse(row.combo),
                    taken.insert(combo).inserted
                else { continue }
                bound.insert(row.lua)
                added.append(row)
            }
        }
        return added
    }
}
