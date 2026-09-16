import Foundation

/// Why a Desktop binding loads no profile, and the ONE judgement
/// of whether a profile's screen count fits the connected one
/// (#1394): Core decides it, the Desktops rows only narrate it
/// (`DesktopBindingFitSeamTests`).
public enum DesktopBindingRefusal: Error {
    /// No bound profile's file could be read.
    case unreadable(Error)
    /// No bound profile is saved for the connected count;
    /// `saved` is the count of each readable one, in binding
    /// order (#1436).
    case screenCount(saved: [Int], connected: Int)
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
                saved: [profileCount],
                connected: connected
            )
        }
        return nil
    }

    /// The log line's tail, after the door names itself.
    func narrative(binding: DesktopBinding) -> String {
        let names = binding.profiles.map { "'\($0)'" }
            .joined(separator: ", ")
        let plural = binding.profiles.count > 1
        switch self {
        case .unreadable(let error):
            return "cannot load profile\(plural ? "s" : "") "
                + "\(names): \(error)"
        case .screenCount(let saved, let connected):
            let counts = saved.map(String.init).joined(separator: ", ")
            return
                "profile\(plural ? "s" : "") \(names) "
                + "\(plural ? "are" : "is") for \(counts) screen(s), "
                + "\(connected) connected; the binding stands aside"
        case .displaysUnknown:
            return
                "profile\(plural ? "s" : "") \(names) "
                + "wait\(plural ? "" : "s") for the first display "
                + "reading; the binding stands aside"
        }
    }
}

/// A binding whose list is empty — a shape no writer produces,
/// named so the gate can refuse it rather than crash.
struct EmptyDesktopBinding: Error {}

extension KiwiCore {
    /// The profile a Desktop binding loads, or why it does not —
    /// the ONE gate every reader of a binding's profile takes
    /// (#1394, `DesktopBindingFitTests`).
    ///
    /// A binding fires only through a bound profile saved for
    /// the connected screen count (#1436: the first in binding
    /// order that is); with none, and before the first display
    /// reading, it stands aside and the rungs below it answer. A
    /// bound load therefore always fits by count.
    func boundProfile(
        of binding: DesktopBinding
    ) -> Result<Profile, DesktopBindingRefusal> {
        let connected = state.workspaces.allDisplays.count
        var saved: [Int] = []
        var unreadable: Error = EmptyDesktopBinding()
        var waiting = false
        for name in binding.profiles {
            let profile: Profile
            do {
                profile = try profiles.read(name: name)
            } catch {
                unreadable = error
                continue
            }
            switch DesktopBindingRefusal.of(
                profileCount: profile.monitorCount,
                connected: connected
            ) {
            case nil:
                return .success(profile)
            case .displaysUnknown?:
                waiting = true
            case .screenCount(let counts, _)?:
                saved += counts
            case .unreadable?:
                break
            }
        }
        if waiting { return .failure(.displaysUnknown) }
        guard saved.isEmpty else {
            return .failure(
                .screenCount(saved: saved, connected: connected)
            )
        }
        return .failure(.unreadable(unreadable))
    }
}
