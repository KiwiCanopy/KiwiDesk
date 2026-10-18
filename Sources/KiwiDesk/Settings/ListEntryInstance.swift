/// A rule-list row's instance (#792): `+entry#n` for the n-th copy
/// of an entry the draft added, `-entry#n` for one it removed. The
/// readout mints it and a revert parses it, so the grammar has this
/// one home; `n` counts copies of the same entry, so a row's id
/// holds when a sibling row leaves.
struct ListEntryInstance: Equatable {
    let added: Bool
    let entry: String
    let occurrence: Int

    var spelled: String {
        (added ? "+" : "-") + entry + "#\(occurrence)"
    }

    init(added: Bool, entry: String, occurrence: Int) {
        self.added = added
        self.entry = entry
        self.occurrence = occurrence
    }

    init?(parsing instance: String) {
        guard let sign = instance.first, sign == "+" || sign == "-",
            let hash = instance.lastIndex(of: "#"),
            hash > instance.startIndex,
            let n = Int(instance[instance.index(after: hash)...])
        else { return nil }
        let start = instance.index(after: instance.startIndex)
        self.init(
            added: sign == "+",
            entry: String(instance[start..<hash]),
            occurrence: n
        )
    }

    /// One instance per entry of `entries`, each copy numbered.
    static func minted(
        _ entries: [String],
        added: Bool
    ) -> [ListEntryInstance] {
        var seen: [String: Int] = [:]
        return entries.map { entry in
            defer { seen[entry, default: 0] += 1 }
            return ListEntryInstance(
                added: added,
                entry: entry,
                occurrence: seen[entry, default: 0]
            )
        }
    }
}
