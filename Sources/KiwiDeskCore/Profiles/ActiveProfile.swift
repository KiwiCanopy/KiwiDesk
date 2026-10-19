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
    /// Its stable id — what a binding names (#2324), so the gate
    /// asks it without reading the file (#1245).
    let id: ProfileID
    let declaredSpaces: Set<SpaceID>
    /// The screen count the profile is saved for — what the
    /// binding door asks about the profile ALREADY live (#1436),
    /// so it never re-reads the file to learn it (#1245).
    let monitorCount: Int
    /// Whether it is the starter setup — what the onboarding and
    /// Settings title ask without re-reading the file (#1662).
    let isStarterSetup: Bool
    /// Its monitor sets — what a bar's per-screen edge write
    /// judges beside the connected screens (#1948,
    /// `KiwiCore.screenEdgeScope(monitorSets:)`). Unlike the
    /// Spaces it follows every write of the file, since a claim
    /// moves a set without an apply (`refiled(_:)`).
    let monitorSets: [MonitorSet]
    /// The lenses it leaves out, by `VisionLens.reachKey` — what
    /// KiwiVision judges the lens on against (#2103 ruling 38).
    /// Like the monitor sets it follows every write of the file,
    /// an "Applies to" edit included.
    let lensesLeftOut: Set<String>

    init(_ profile: Profile) {
        name = profile.name
        id = profile.id
        declaredSpaces = profile.declaredSpaces
        monitorCount = profile.monitorCount
        isStarterSetup = profile.isStarterSetup
        monitorSets = profile.monitorSets
        lensesLeftOut = Self.leftOut(profile)
    }

    private init(
        name: String,
        id: ProfileID,
        declaredSpaces: Set<SpaceID>,
        monitorCount: Int,
        isStarterSetup: Bool,
        monitorSets: [MonitorSet],
        lensesLeftOut: Set<String>
    ) {
        self.name = name
        self.id = id
        self.declaredSpaces = declaredSpaces
        self.monitorCount = monitorCount
        self.isStarterSetup = isStarterSetup
        self.monitorSets = monitorSets
        self.lensesLeftOut = lensesLeftOut
    }

    private static func leftOut(_ profile: Profile) -> Set<String> {
        Set(
            (profile.lensReach ?? [:]).filter { !$0.value }.keys
                .map(VisionLens.reachKey)
        )
    }

    /// A rename moves the name; the Spaces are unchanged by it.
    func renamed(to new: String) -> ActiveProfile {
        ActiveProfile(
            name: new,
            id: id,
            declaredSpaces: declaredSpaces,
            monitorCount: monitorCount,
            isStarterSetup: isStarterSetup,
            monitorSets: monitorSets,
            lensesLeftOut: lensesLeftOut
        )
    }

    /// The live profile after a write of its file: the monitor
    /// sets and the lens reach follow it; the name and Spaces stay
    /// the apply's.
    func refiled(_ profile: Profile) -> ActiveProfile {
        guard profile.name == name else { return self }
        return ActiveProfile(
            name: name,
            id: id,
            declaredSpaces: declaredSpaces,
            monitorCount: monitorCount,
            isStarterSetup: isStarterSetup,
            monitorSets: profile.monitorSets,
            lensesLeftOut: Self.leftOut(profile)
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
    /// The starter's title when this Standard is the starter.
    let title: StarterTitle?
}
