import Foundation

/// A Space added to or removed from the live profile's file
/// (#1790): `create_space`/`delete_space` with `profile`, the
/// bar's confirmed Delete and Settings ▸ Spaces' add button all
/// write here, through the live-write door.
extension KiwiCore {
    /// Why a Space cannot move into or out of the profile. English:
    /// the CLI's machine contract; the GUI greys by `canAddToProfile`.
    enum ProfileScopeRefusal: Error, CustomStringConvertible {
        case noProfile
        case declaredElsewhere(String)
        case held
        case notWritten

        var description: String {
            switch self {
            case .noProfile:
                return "no profile is live; save this setup as a profile first"
            case .declaredElsewhere(let source):
                return "\(source) declares this space; it is not the profile's"
            case .held:
                return "a held space goes home with its own profile"
            case .notWritten:
                return "the profile file was not written"
            }
        }
    }

    /// Whether `id` could be added to the live profile now: it is
    /// temporary and a profile file is live. Settings greys its
    /// add button on this.
    public func canAddToProfile(_ id: SpaceID) -> Bool {
        isTemporary(id) && profiles.currentName != nil
    }

    /// Writes live Space `id` into the live profile — its place in
    /// the list, mode, pin and icon — and it stops being temporary.
    /// A Space the profile already declares is a no-op.
    func addToProfile(
        _ id: SpaceID
    ) -> Result<Void, ProfileScopeRefusal> {
        if let refusal = profileScopeRefusal(of: id) {
            return .failure(refusal)
        }
        guard let space = state.workspaces[id],
            profiles.active?.declaredSpaces.contains(id) != true
        else { return .success(()) }
        let order = state.workspaces.allSpaces.map(\.id)
        let declared = profiles.active?.declaredSpaces ?? []
        let after = order.prefix { $0 != id }.last { declared.contains($0) }
        let added = AddedSpace(
            after: after,
            mode: space.mode,
            pin: spacePins[id],
            icon: tiler.settings.spaceIcons[id]
        )
        guard writeThroughLiveProfile(.addSpace(id, added)) else {
            return .failure(.notWritten)
        }
        syncGuiSpacesToLive()
        updateBars()
        return .success(())
    }

    /// Removes `id` from the live profile's file; the caller
    /// deletes the live Space. A Space the profile does not declare
    /// has nothing to remove.
    func removeFromProfile(
        _ id: SpaceID
    ) -> Result<Void, ProfileScopeRefusal> {
        if let refusal = profileScopeRefusal(of: id) {
            return .failure(refusal)
        }
        guard profiles.active?.declaredSpaces.contains(id) == true else {
            return .success(())
        }
        return writeThroughLiveProfile(.removeSpace(id))
            ? .success(()) : .failure(.notWritten)
    }

    /// Why `profile` scope refuses `id`, naming the other source
    /// that declares it.
    func profileScopeRefusal(of id: SpaceID) -> ProfileScopeRefusal? {
        guard profiles.currentName != nil else { return .noProfile }
        if state.heldSpaces[id] != nil { return .held }
        let other = declaredSources(of: id).first { !$0.hasPrefix("profile:") }
        return other.map { .declaredElsewhere($0) }
    }
}
