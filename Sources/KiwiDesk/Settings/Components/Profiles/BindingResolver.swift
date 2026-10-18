import KiwiDeskCore

/// How the Desktops card reads a binding entry against the saved
/// profiles (#2324): by id where the entry names one — so a
/// profile renamed on another Mac shows its current name and a
/// deleted one reads as gone, whatever its label says — and by
/// name for a pending entry. The one lens every card reader takes,
/// never a name→count map beside it.
struct BindingResolver: Equatable {
    /// Each readable saved profile's current name, by id.
    let names: [ProfileID: String]
    /// Each readable saved profile's screen count, by name.
    let counts: [String: Int]

    init(_ profiles: [ProfileSummary]) {
        names = Dictionary(
            profiles.map { ($0.profileID, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )
        counts = Dictionary(
            profiles.map { ($0.name, $0.count) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// A resolver over profiles known by name alone — pending
    /// entries resolve, entries naming an id do not.
    init(counts: [String: Int]) {
        names = [:]
        self.counts = counts
    }

    /// The saved profile `entry` names, nil where none does.
    func name(of entry: DesktopBinding.Entry) -> String? {
        if let id = entry.id { return names[id] }
        return counts[entry.name] == nil ? nil : entry.name
    }

    /// What a row shows: the saved profile's name, else the label.
    func shownName(of entry: DesktopBinding.Entry) -> String {
        name(of: entry) ?? entry.name
    }

    /// The screen count `entry`'s profile is saved for, nil where
    /// it has none — the binding algebra's `countOf`.
    func count(of entry: DesktopBinding.Entry) -> Int? {
        name(of: entry).flatMap { counts[$0] }
    }

    /// The entry a pick of the saved profile `name` files.
    func entry(
        named name: String,
        setup: [String]? = nil
    ) -> DesktopBinding.Entry {
        DesktopBinding.Entry(
            id: names.first { $0.value == name }?.key,
            name: name,
            setup: setup
        )
    }

    /// The live profile as a binding names it.
    func live(_ name: String?) -> (id: ProfileID, name: String)? {
        guard let name,
            let id = names.first(where: { $0.value == name })?.key
        else { return nil }
        return (id, name)
    }
}
