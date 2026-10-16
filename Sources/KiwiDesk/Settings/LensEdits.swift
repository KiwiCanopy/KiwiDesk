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

    /// The draft that changes nothing.
    init(stored: [VisionLens]) {
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

    /// `list` with the draft's changes laid over it: every page
    /// lens in page order, then whatever `list` holds that the
    /// draft never stored — a session `define_lens` lives on in the
    /// live list, and the settled list has none. A deleted lens
    /// goes. One name comparison throughout (`sameLens`).
    func applied(to list: [VisionLens]) -> [VisionLens] {
        let named = lenses.compactMap(\.stored) + deleted
        let extras = list.filter { lens in
            !named.contains { AppWideSettings.sameLens($0, lens.name) }
                && !lenses.contains {
                    AppWideSettings.sameLens($0.lens.name, lens.name)
                }
        }
        return AppWideSettings.lensEntries(current + extras)
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
