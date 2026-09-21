import Foundation

/// The active profile: its name, and the Spaces it declares.
///
/// ONE value rather than two fields, so no writer can move the
/// name and leave the Spaces behind — profiles.md ▸ "Whose
/// arrangement is live" and "Answer a Desktop switch from
/// adoption state" (#1249, #1245).
///
/// The Spaces are the ones the last APPLY carried, not the file's
/// current contents: a hand edit reaches this at the next apply
/// (a reload, a monitor change, an in-effect save). That is why a
/// rename carries the Spaces across rather than re-reading the
/// profile it already holds — a rename is not an apply, and
/// refreshing there would let the declared set disagree with the
/// live Spaces no apply had changed.
struct ActiveProfile {
    let name: String
    let declaredSpaces: Set<SpaceID>
    /// The screen count the profile is saved for — what the
    /// binding door asks about the profile ALREADY live (#1436),
    /// so it never re-reads the file to learn it (#1245).
    let monitorCount: Int

    init(_ profile: Profile) {
        name = profile.name
        declaredSpaces = profile.declaredSpaces
        monitorCount = profile.monitorCount
    }

    private init(
        name: String,
        declaredSpaces: Set<SpaceID>,
        monitorCount: Int
    ) {
        self.name = name
        self.declaredSpaces = declaredSpaces
        self.monitorCount = monitorCount
    }

    /// A rename moves the name; the Spaces are unchanged by it.
    func renamed(to new: String) -> ActiveProfile {
        ActiveProfile(
            name: new,
            declaredSpaces: declaredSpaces,
            monitorCount: monitorCount
        )
    }
}

/// The built-in Standard resolving live: its name and the Spaces
/// it composed, one value for the same reason as `ActiveProfile`
/// — a reload recomposes it, so `delete_space` names it as a
/// re-creator from here, never by composing again (#1509).
struct ActiveStandard {
    let name: String
    let spaces: Set<SpaceID>
}
