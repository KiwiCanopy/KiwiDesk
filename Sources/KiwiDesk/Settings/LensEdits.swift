import Foundation
import KiwiDeskCore

/// The Settings lens page's draft over the STORED lenses (#2103
/// rulings 29, 38, 39, 40): the whole list as the page holds it,
/// each lens with the name it is stored under, the stored lenses
/// it deleted and the profiles each one is picked to reach. Seeded
/// from `KiwiCore.kiwiVisionStoredLenses`, never the live list, so
/// a session `define_lens` or `delete_lens` never reaches a Save.
struct LensEdits: Equatable {
    var lenses: [DraftLens]
    /// Stored names the draft deleted.
    var deleted: [String] = []
    /// The saved profiles each lens reaches, keyed by its page
    /// name; a lens it does not name keeps its stored reach.
    var reach: [String: Set<String>] = [:]

    /// The stored lenses the draft was seeded from.
    let seed: [VisionLens]

    /// The draft that changes nothing.
    init(stored: [VisionLens]) {
        seed = stored
        lenses = stored.map { DraftLens(lens: $0, stored: $0.name) }
    }

    /// The page's lenses, in order.
    var current: [VisionLens] { lenses.map(\.lens) }

    /// Every rename, stored name → page name; a respelling counts.
    var renames: [String: String] {
        var map: [String: String] = [:]
        for draft in lenses {
            if let stored = draft.stored, stored != draft.lens.name {
                map[stored] = draft.lens.name
            }
        }
        return map
    }

    /// Whether a Save of this draft writes nothing.
    func isInert(over stored: [VisionLens]) -> Bool {
        current == stored && deleted.isEmpty && reach.isEmpty
    }

    /// `list` with the draft's CHANGES laid over it: a deleted lens
    /// goes, an edited or renamed one replaces its stored name's
    /// entry in place, a new one is appended, and a lens the draft
    /// left as stored keeps whatever `list` holds for it — so on the
    /// live list a session `define_lens` or `delete_lens` survives a
    /// Save, and on the settled list the result is the page's. Every
    /// target is found before any write, so a swap merges nothing. One
    /// name comparison throughout (`sameLens`).
    func applied(to list: [VisionLens]) -> [VisionLens] {
        var result = list.filter { lens in
            !deleted.contains { AppWideSettings.sameLens($0, lens.name) }
        }
        // Every target found in the list as it was, so a swap's
        // second rename cannot land on the first one's write.
        let changed = lenses.filter { draft in
            draft.lens
                != draft.stored.flatMap { name in
                    seed.first { $0.name == name }
                }
        }
        let targets = changed.map { draft in
            let key = draft.stored ?? draft.lens.name
            return result.firstIndex {
                AppWideSettings.sameLens($0.name, key)
            }
        }
        for (draft, at) in zip(changed, targets) {
            if let at {
                result[at] = draft.lens
            } else {
                result.append(draft.lens)
            }
        }
        return AppWideSettings.lensEntries(result)
    }
}

/// A lens on the page and the name it is stored under, nil for a
/// lens the draft created.
struct DraftLens: Equatable {
    var lens: VisionLens
    let stored: String?
}

/// Why a lens name is refused (ruling 39).
enum LensNameRefusal: Equatable {
    case empty
    /// Over `AppWideSettings.lensNameLimit` characters.
    case tooLong
    /// Another lens has it, ignoring case.
    case taken(String)

    /// The refusal for `raw` among `others`' names, nil where it
    /// may stand.
    static func of(_ raw: String, among others: [String]) -> Self? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return .empty }
        if name.count > AppWideSettings.lensNameLimit { return .tooLong }
        if let holder = others.first(where: {
            AppWideSettings.sameLens($0, name)
        }) {
            return .taken(holder)
        }
        return nil
    }
}
