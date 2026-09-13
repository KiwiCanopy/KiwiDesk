import Foundation

/// Why the profile a Desktop binding names does not load, and
/// the ONE judgement of whether a profile's screen count fits the
/// connected one (#1394): Core decides it, the Desktops row only
/// narrates it (`DesktopBindingFitSeamTests`).
public enum DesktopBindingRefusal: Error {
    /// The profile's file could not be read.
    case unreadable(Error)
    /// The profile is saved for another screen count.
    case screenCount(profile: Int, connected: Int)
    /// No display reading yet: the first config load runs before
    /// the loop publishes displays, and a paused engine discovers
    /// none. The first monitor change re-judges.
    case displaysUnknown

    /// The count verdict alone, pure; nil where `profileCount`
    /// fits `connected`.
    public static func of(
        profileCount: Int,
        connected: Int
    ) -> DesktopBindingRefusal? {
        if connected == 0 { return .displaysUnknown }
        guard profileCount == connected else {
            return .screenCount(
                profile: profileCount,
                connected: connected
            )
        }
        return nil
    }

    /// The log line's tail, after the door names itself.
    func narrative(profile name: String) -> String {
        switch self {
        case .unreadable(let error):
            return "cannot load profile '\(name)': \(error)"
        case .screenCount(let profile, let connected):
            return
                "profile '\(name)' is for \(profile) screen(s), "
                + "\(connected) connected; the binding stands aside"
        case .displaysUnknown:
            return
                "profile '\(name)' waits for the first display "
                + "reading; the binding stands aside"
        }
    }
}

extension KiwiCore {
    /// The profile a Desktop binding loads, or why it does not —
    /// the ONE gate every reader of a binding's profile takes
    /// (#1394, `DesktopBindingFitTests`).
    ///
    /// A binding fires only where its profile is saved for the
    /// connected screen count; for any other count, and before
    /// the first display reading, it stands aside and the rungs
    /// below it answer. A bound load therefore always fits by
    /// count.
    func boundProfile(
        of binding: DesktopBinding
    ) -> Result<Profile, DesktopBindingRefusal> {
        let profile: Profile
        do {
            profile = try profiles.read(name: binding.profile)
        } catch {
            return .failure(.unreadable(error))
        }
        if let refusal = DesktopBindingRefusal.of(
            profileCount: profile.monitorCount,
            connected: state.workspaces.allDisplays.count
        ) {
            return .failure(refusal)
        }
        return .success(profile)
    }
}
