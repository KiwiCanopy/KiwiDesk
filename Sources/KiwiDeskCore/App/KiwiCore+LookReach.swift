import Foundation

/// The "Look applies to" checklist's writes (#1752): which profiles
/// follow the shared look. A Settings Save commits them through the
/// one `saveLookReach`, the look's sibling of `saveRuleReach`, with
/// that door's obligations (profiles.md ▸ A Settings Save may write
/// OTHER profiles' files).
extension KiwiCore {
    /// Whether each stored profile follows the shared look —
    /// true, or false where it keeps its own. A profile that cannot
    /// be read is left out, as the rule checklist leaves it out.
    public func lookReach() -> [String: Bool] {
        var reach: [String: Bool] = [:]
        for name in profiles.list() {
            guard let profile = try? profiles.read(name: name) else {
                continue
            }
            reach[name] = profile.look == nil
        }
        return reach
    }

    /// Writes each switch `follows` names, and only those that
    /// changed: a profile going `own` freezes the look it wears NOW
    /// into its file, so nothing on screen moves; a profile going
    /// shared has its copy re-stamped to the shared look, and with no
    /// shared look yet its look seeds one through the crossing's
    /// election. Writes are non-adopting, so reaching another
    /// profile never moves `currentName`; the live screen's look is
    /// re-resolved, never the whole profile re-applied
    /// (`LookReachTests`).
    /// Call it before any `gui.json` write of the same Save.
    public func saveLookReach(_ follows: [String: Bool]) throws {
        for (name, follow) in follows.sorted(by: { $0.key < $1.key }) {
            let look: LookReference? = follow ? nil : .own
            var profile = try profiles.read(name: name)
            guard profile.look != look else { continue }
            if look == nil, sharedLook == nil, isGuiManaged {
                // No shared look yet: this one's look seeds it, and
                // the election settles every other profile.
                crossWith(LookBody(of: profile.settings))
                profile = try profiles.read(name: name)
                guard profile.look != look else { continue }
            }
            if look == .own {
                profile.settings = resolvedSettings(of: profile)
            } else {
                profile.settings = wearingSharedLook(profile.settings)
            }
            profile.look = look
            try profiles.write(profile)
        }
        reresolveLiveLook()
    }
}
