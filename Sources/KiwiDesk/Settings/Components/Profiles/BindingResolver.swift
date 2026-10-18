import KiwiDeskCore

/// Core's verdict per binding entry, as the model holds it.
typealias BindingResolutions =
    [DesktopBinding.Entry.Key: BindingResolution]

/// How the Desktops card reads a binding entry (#2324): through
/// Core's one `BindingResolution` per entry, which the model reads
/// at refresh — so the card never decides "missing" or "couldn't
/// load" itself, and a profile renamed on another Mac shows its
/// current name. The one lens every card reader takes.
struct BindingResolver: Equatable {
    /// Core's verdict per entry, from the last refresh.
    let resolutions: [DesktopBinding.Entry.Key: BindingResolution]
    /// Each readable saved profile's screen count, by name.
    let counts: [String: Int]
    /// The saved profiles' ids, by name — what a picker's pick
    /// files, never a lookup of a stored entry.
    let pickable: [String: ProfileID]
    /// The live profile, from adoption state.
    let liveID: ProfileID?

    init(
        _ profiles: [ProfileSummary],
        resolutions: [DesktopBinding.Entry.Key: BindingResolution],
        liveID: ProfileID?
    ) {
        self.resolutions = resolutions
        counts = Dictionary(
            profiles.map { ($0.name, $0.count) },
            uniquingKeysWith: { first, _ in first }
        )
        pickable = Dictionary(
            profiles.map { ($0.name, $0.profileID) },
            uniquingKeysWith: { first, _ in first }
        )
        self.liveID = liveID
    }

    /// A resolver over pending entries known by name alone, for a
    /// fixture with no Core to resolve through.
    init(counts: [String: Int]) {
        resolutions = [:]
        self.counts = counts
        pickable = [:]
        liveID = nil
    }

    /// The saved profile `entry` names, nil where none does. An
    /// entry a pick filed since the last refresh — not resolved by
    /// Core yet — reads the name it was picked by.
    func name(of entry: DesktopBinding.Entry) -> String? {
        switch resolutions[entry.key] {
        case .profile(let file)?: return file
        case .unreadable?, .missing?: return nil
        case nil:
            if let id = entry.id {
                return pickable[entry.name] == id ? entry.name : nil
            }
            return counts[entry.name] == nil ? nil : entry.name
        }
    }

    /// Whether Core read `entry`'s profile file and it will not
    /// decode.
    func isUnreadable(_ entry: DesktopBinding.Entry) -> Bool {
        if case .unreadable? = resolutions[entry.key] { return true }
        return false
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
        DesktopBinding.Entry(id: pickable[name], name: name, setup: setup)
    }

    /// The live profile as a binding names it, its id from
    /// adoption state.
    func live(_ name: String?) -> (id: ProfileID, name: String)? {
        guard let name, let liveID else { return nil }
        return (liveID, name)
    }
}
