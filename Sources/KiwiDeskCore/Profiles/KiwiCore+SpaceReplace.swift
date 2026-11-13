import Foundation

/// The tour's replay over a changed desk (#3294): a preset replaces
/// the live profile's Spaces IN PLACE — the profile keeps its id,
/// name, rules, layers, settings, look and Desktop bindings — and
/// the step's Revert puts the saved Spaces back.
extension KiwiCore {
    /// What a Revert of a replace returns to: the live profile's
    /// Spaces before the replace, and whose they were.
    public struct TourSpacesBaseline: Equatable, Sendable {
        let profile: String
        let spaces: SpaceSet
    }

    /// `layout` composed onto the live screens as a Space set; nil
    /// where it plans more screens than are connected.
    public func spaceSet(for layout: StandardLayout) -> SpaceSet? {
        let displays = state.workspaces.allDisplays
        guard displays.count >= layout.screenCount,
            let composed = ProfileComposition.compose(
                layout: layout,
                displays: displays,
                mainID: PositionalDisplays.liveMainID
            )
        else { return nil }
        let placement = composedPlacement(composed)
        return SpaceSet(
            spaces: composed.spaces,
            spaceModes: composed.spaceModes,
            mainSpaces: placement.mains,
            pins: placement.pins
        )
    }

    /// The live profile's saved Spaces, for a later Revert; nil
    /// where no saved profile is live or it cannot be read.
    public func tourSpacesBaseline() -> TourSpacesBaseline? {
        guard let name = profiles.currentName,
            let profile = try? profiles.read(name: name)
        else { return nil }
        return TourSpacesBaseline(
            profile: name,
            spaces: profile.spaceSet(monitors: liveFingerprints)
        )
    }

    /// Replaces the live profile's Spaces with `layout`'s, written
    /// through and applied; false where nothing was written.
    @discardableResult
    public func replaceSpaces(with layout: StandardLayout) -> Bool {
        guard let set = spaceSet(for: layout) else { return false }
        return writeSpaces(set)
    }

    /// Puts back the Spaces `baseline` saved; refused once another
    /// profile is live.
    @discardableResult
    public func restoreSpaces(_ baseline: TourSpacesBaseline) -> Bool {
        guard baseline.profile == profiles.currentName else {
            return false
        }
        return writeSpaces(baseline.spaces)
    }

    /// The app rules that send an app to a Space `set` drops, by
    /// that Space: such an app opens a Space of its own (#3294).
    public func appRulesLeftBehind(by set: SpaceSet) -> [SpaceID: Int] {
        let kept = Set(set.spaces)
        var counts: [SpaceID: Int] = [:]
        for target in state.appRules.values where !kept.contains(target) {
            counts[target, default: 0] += 1
        }
        return counts
    }

    private func writeSpaces(_ set: SpaceSet) -> Bool {
        guard writeThroughLiveProfile(.replaceSpaces(set)),
            let name = profiles.currentName,
            let profile = try? profiles.read(name: name)
        else { return false }
        apply(profile: profile, cause: .edit)
        return true
    }
}
