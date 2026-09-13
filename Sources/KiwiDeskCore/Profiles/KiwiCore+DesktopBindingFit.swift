import Foundation

/// Why the profile a Desktop binding names does not load.
enum DesktopBindingRefusal: Error {
    /// The profile's file could not be read.
    case unreadable(Error)
    /// The profile is saved for another screen count (#1394).
    case screenCount(profile: Int, connected: Int)

    /// The log line's tail, after the door names itself.
    func narrative(profile name: String) -> String {
        switch self {
        case .unreadable(let error):
            return "cannot load profile '\(name)': \(error)"
        case .screenCount(let profile, let connected):
            return
                "profile '\(name)' is for \(profile) screen(s), "
                + "\(connected) connected; the binding stands aside"
        }
    }
}

extension KiwiCore {
    /// The profile a Desktop binding loads, or why it does not —
    /// the ONE gate every reader of a binding's profile takes
    /// (#1394, `DesktopBindingFitTests`).
    ///
    /// A binding fires only where its profile is saved for the
    /// connected screen count; for any other count it stands
    /// aside and the rungs below it answer. A bound load
    /// therefore always fits by count, which is why no door
    /// marks clean or dirty beside its apply (#1332).
    ///
    /// An unknown display set — the first config load runs
    /// before the loop publishes displays, and a paused engine
    /// discovers none — cannot judge and lets the binding
    /// through; the first monitor change re-judges it here.
    func boundProfile(
        of binding: DesktopBinding
    ) -> Result<Profile, DesktopBindingRefusal> {
        let profile: Profile
        do {
            profile = try profiles.read(name: binding.profile)
        } catch {
            return .failure(.unreadable(error))
        }
        let connected = state.workspaces.allDisplays.count
        guard connected == 0 || profile.monitorCount == connected
        else {
            return .failure(
                .screenCount(
                    profile: profile.monitorCount,
                    connected: connected
                )
            )
        }
        return .success(profile)
    }
}
