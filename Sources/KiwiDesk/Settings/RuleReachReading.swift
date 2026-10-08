import KiwiDeskCore

/// One App Rules row's "Applies to" checklist, read off the draft
/// (#1393). Every tick, ⚠ and label is relative to `editing`.
struct RuleReachReading: Equatable {
    let editing: String
    let loaded: String?
    /// Every readable profile, in the edit-target menu's order.
    let profiles: [String]
    let unreadable: [String]
    /// Whether the row is the shared rule.
    var shared: Bool
    /// Whether a shared rule exists for this row's subject, which a
    /// profile created later inherits.
    let hasShared: Bool
    /// The profiles that resolve this row's value, `editing` too —
    /// or, while a picked list waits for a value, the ticked ones.
    var users: Set<String>
    /// Profiles resolving a DIFFERENT value, in its words.
    let own: [String: String]
    /// Those of `own` whose value is the shared rule.
    let ownIsShared: Set<String>
    /// Profiles that leave this shared rule out.
    var leftOut: Set<String>
    /// Profiles the draft's pick ticked into the shared rule — still
    /// tickable until the Save, so a tick can be taken back.
    var joined: Set<String> = []
    /// A shortcut's combo that another profile binds to a
    /// different action, in that action's words — ticking takes
    /// the key over.
    var takenBy: [String: String] = [:]
    /// Profiles without a shortcut's layer (#2022) — their box
    /// greys.
    var lacking: Set<String> = []
    /// Whether a shortcut's layer is the shared base's; All
    /// profiles greys where it is not (#2022).
    var layerShared = true

    /// Whether `profile`'s box is the edited profile's, locked.
    func isLocked(_ profile: String) -> Bool { profile == editing }

    /// Whether `profile`'s box follows All profiles — ticked and
    /// greyed. One with its own value, or left out, stays
    /// tickable, which drops that value.
    func follows(_ profile: String) -> Bool {
        shared && own[profile] == nil && !leftOut.contains(profile)
            && !joined.contains(profile)
    }

    /// Whether All profiles can be ticked: the row is shared, or
    /// its layer is (#2022).
    var allTickable: Bool { shared || layerShared }

    /// The profiles the row ⚠ names, in menu order.
    var differing: [String] {
        profiles.filter { own[$0] != nil || leftOut.contains($0) }
    }
}
