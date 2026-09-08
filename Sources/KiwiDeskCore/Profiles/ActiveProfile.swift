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

    init(_ profile: Profile) {
        name = profile.name
        declaredSpaces = profile.declaredSpaces
    }

    private init(name: String, declaredSpaces: Set<SpaceID>) {
        self.name = name
        self.declaredSpaces = declaredSpaces
    }

    /// A rename moves the name; the Spaces are unchanged by it.
    func renamed(to new: String) -> ActiveProfile {
        ActiveProfile(name: new, declaredSpaces: declaredSpaces)
    }
}
