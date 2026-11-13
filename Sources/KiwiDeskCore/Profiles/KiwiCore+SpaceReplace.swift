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
        guard let composed = composedOnLive(layout) else { return nil }
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
        guard let name = profiles.currentName,
            let profile = try? profiles.read(name: name),
            keepsLiveScreens(profile),
            let set = spaceSet(for: layout)
        else { return false }
        return writeSpaces(set)
    }

    /// Whether `profile` keeps a layout for the connected screens,
    /// so a replace can record which screen each Space is on.
    func keepsLiveScreens(_ profile: Profile) -> Bool {
        profile.set(matching: liveFingerprints) != nil
    }

    /// `layout` composed onto the live screens — the one composition
    /// the apply, the replace and the tour's picture take; nil where
    /// it does not plan for this many screens.
    func composedOnLive(
        _ layout: StandardLayout
    ) -> ProfileComposition.Composed? {
        let displays = state.workspaces.allDisplays
        guard layout.plans(forScreens: displays.count) else { return nil }
        return ProfileComposition.compose(
            layout: layout,
            displays: displays,
            mainID: PositionalDisplays.liveMainID
        )
    }

    /// Puts back the Spaces `baseline` saved; refused once another
    /// profile is live.
    @discardableResult
    public func restoreSpaces(_ baseline: TourSpacesBaseline) -> Bool {
        // The live-profile rule `TourBaseline` keeps for the looks:
        // a baseline describes the profile it was taken from.
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
        let before = capturedSpaces.map(\.id)
        guard writeThroughLiveProfile(.replaceSpaces(set)),
            let name = profiles.currentName,
            let profile = try? profiles.read(name: name)
        else { return false }
        apply(profile: profile, cause: .edit)
        dropSpaces(
            before.filter { !set.spaces.contains($0) },
            into: set.fallbackSpace ?? set.spaces.first
        )
        // A larger set than before binds ⌃⌥N for its newcomers, as
        // `applyStandard` does (#485).
        topUpDigitShortcuts()
        return true
    }

    /// Drops the Spaces a replace leaves out — a same-profile apply
    /// keeps an undeclared Space as a temporary one (#1790) —
    /// through `delete_space`'s own delete, their windows forwarded
    /// to `target`, a Space the set keeps.
    private func dropSpaces(_ dropped: [SpaceID], into target: SpaceID?) {
        guard let target else { return }
        for id in dropped where state.workspaces[id] != nil {
            let response = deleteSpace(id, forwardingTo: target)
            if !response.isSuccess {
                onLog(
                    "tour: Space \(id.raw) stays: "
                        + (response.error ?? response.status)
                )
            }
        }
    }
}
